#!/usr/bin/env python3
"""Validate the canonical progressive Markdown task tracker."""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple
from urllib.parse import unquote, urlsplit


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ROOT_TRACKER = PROJECT_ROOT / "docs" / "CAPABILITY_LEDGER.md"
TRACKER_DIRECTORY = PROJECT_ROOT / "docs" / "trackers"
MAX_TASKS_PER_FILE = 15

EXPECTED_ROOT_SCOPES = [
    "Mojo language and compiler",
    "Standard library and native dependencies",
    "Standard MAX",
    "Embedded runtime",
    "Async and concurrency",
    "Swift ABI and AOT artifacts",
    "Metal",
    "Core AI and ANE",
    "Targets and hardware",
    "App Store distribution",
    "Upstream and tracking sustainability",
]

TASK_PATTERN = re.compile(
    r"^(?P<indent> *)- \[(?P<mark>[ xX])\] "
    r"\*\*(?P<name>[^*\n]+)\*\*: (?P<description>\S.*)$"
)
TASK_PREFIX_PATTERN = re.compile(r"^\s*[-+*]\s+\[[^]]*\]")
TRACKER_LINK_PATTERN = re.compile(r"\[tracker\]\(([^)]+)\)", re.IGNORECASE)
MARKDOWN_LINK_PATTERN = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")
HEADING_PATTERN = re.compile(r"^#{1,6}\s+(.+?)\s*#*\s*$")
PARENT_PATTERN = re.compile(r"^Parent: \[[^]]+\]\(([^)]+)\)$", re.MULTILINE)


class TrackerError(Exception):
    pass


@dataclass
class Task:
    source_path: Path
    line_number: int
    indent: int
    checked: bool
    name: str
    description: str
    children: List["Task"] = field(default_factory=list)
    tracker_path: Optional[Path] = None

    @property
    def location(self) -> str:
        return f"{relative(self.source_path)}:{self.line_number}"


@dataclass
class TrackerFile:
    path: Path
    text: str
    top_level_tasks: List[Task]
    all_tasks: List[Task]
    heading_anchors: Set[str]


def relative(path: Path) -> str:
    return str(path.relative_to(PROJECT_ROOT))


def fail(message: str) -> None:
    raise TrackerError(message)


def github_heading_anchors(text: str) -> Set[str]:
    anchors: Set[str] = set()
    occurrences: Dict[str, int] = {}
    for line in text.splitlines():
        match = HEADING_PATTERN.match(line)
        if match is None:
            continue
        heading = re.sub(r"<[^>]+>", "", match.group(1)).strip().lower()
        heading = re.sub(r"[^\w\- ]", "", heading)
        base_anchor = re.sub(r"\s+", "-", heading)
        occurrence = occurrences.get(base_anchor, 0)
        occurrences[base_anchor] = occurrence + 1
        anchor = base_anchor if occurrence == 0 else f"{base_anchor}-{occurrence}"
        anchors.add(anchor)
    return anchors


def parse_tracker(path: Path) -> TrackerFile:
    text = path.read_text(encoding="utf-8")
    top_level_tasks: List[Task] = []
    all_tasks: List[Task] = []
    stack: List[Task] = []

    for line_number, line in enumerate(text.splitlines(), start=1):
        task_match = TASK_PATTERN.match(line)
        if task_match is None:
            if TASK_PREFIX_PATTERN.match(line):
                fail(
                    f"{relative(path)}:{line_number}: malformed task row; expected "
                    "'- [ ] **Name**: Description'"
                )
            continue

        indent = len(task_match.group("indent"))
        if indent % 2 != 0:
            fail(f"{relative(path)}:{line_number}: task indentation must use two spaces")

        name = task_match.group("name").strip()
        description = task_match.group("description").strip()
        if "not decomposed" in description.casefold():
            fail(
                f"{relative(path)}:{line_number}: decomposition is structure, not a "
                "status or description"
            )

        while stack and stack[-1].indent >= indent:
            stack.pop()

        task = Task(
            source_path=path,
            line_number=line_number,
            indent=indent,
            checked=task_match.group("mark").casefold() == "x",
            name=name,
            description=description,
        )

        if indent == 0:
            top_level_tasks.append(task)
        else:
            if not stack or stack[-1].indent != indent - 2:
                fail(
                    f"{task.location}: task indentation skips a parent level"
                )
            stack[-1].children.append(task)

        stack.append(task)
        all_tasks.append(task)

    if not all_tasks:
        fail(f"{relative(path)}: tracker contains no task rows")
    if len(all_tasks) > MAX_TASKS_PER_FILE:
        fail(
            f"{relative(path)}: {len(all_tasks)} task rows exceed the glanceable "
            f"limit of {MAX_TASKS_PER_FILE}; split the branch"
        )

    for parent_tasks in sibling_groups(top_level_tasks):
        seen_names: Dict[str, Task] = {}
        for task in parent_tasks:
            normalized_name = task.name.casefold()
            if normalized_name in seen_names:
                first = seen_names[normalized_name]
                fail(
                    f"{task.location}: duplicate sibling scope '{task.name}' "
                    f"(first at {first.location})"
                )
            seen_names[normalized_name] = task

    return TrackerFile(
        path=path,
        text=text,
        top_level_tasks=top_level_tasks,
        all_tasks=all_tasks,
        heading_anchors=github_heading_anchors(text),
    )


def sibling_groups(top_level_tasks: List[Task]) -> Iterable[List[Task]]:
    yield top_level_tasks
    for task in top_level_tasks:
        yield from sibling_groups(task.children)


def resolve_local_link(source_path: Path, raw_target: str) -> Tuple[Path, str]:
    target = raw_target.strip()
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1]
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc:
        fail(f"{relative(source_path)}: expected a local tracker link, got {raw_target}")
    if parsed.path.startswith("/"):
        fail(f"{relative(source_path)}: tracker links must be repository-relative")
    target_path = source_path if not parsed.path else source_path.parent / unquote(parsed.path)
    return target_path.resolve(), unquote(parsed.fragment)


def validate_markdown_links(tracker: TrackerFile, trackers: Dict[Path, TrackerFile]) -> None:
    for line_number, line in enumerate(tracker.text.splitlines(), start=1):
        for match in MARKDOWN_LINK_PATTERN.finditer(line):
            raw_target = match.group(1).strip()
            parsed = urlsplit(raw_target.strip("<>"))
            if parsed.scheme or parsed.netloc:
                continue
            target_path, fragment = resolve_local_link(tracker.path, raw_target)
            if not target_path.exists():
                fail(
                    f"{relative(tracker.path)}:{line_number}: broken link to "
                    f"{raw_target}"
                )
            if fragment:
                target_tracker = trackers.get(target_path)
                if target_tracker is None:
                    target_text = target_path.read_text(encoding="utf-8")
                    anchors = github_heading_anchors(target_text)
                else:
                    anchors = target_tracker.heading_anchors
                if fragment.casefold() not in anchors:
                    fail(
                        f"{relative(tracker.path)}:{line_number}: missing anchor "
                        f"#{fragment} in {relative(target_path)}"
                    )


def descendant_tasks(tasks: Iterable[Task]) -> Iterable[Task]:
    for task in tasks:
        yield task
        yield from descendant_tasks(task.children)


def validate_checked_rollup(
    task: Task,
    trackers: Dict[Path, TrackerFile],
    visited_files: Optional[Set[Path]] = None,
) -> None:
    if not task.checked:
        return

    for child in descendant_tasks(task.children):
        if not child.checked:
            fail(
                f"{task.location}: checked parent '{task.name}' has unchecked "
                f"descendant '{child.name}' at {child.location}"
            )

    if task.tracker_path is None:
        return

    visited = set() if visited_files is None else set(visited_files)
    if task.tracker_path in visited:
        fail(f"{task.location}: tracker delegation cycle detected")
    visited.add(task.tracker_path)
    delegated_tracker = trackers[task.tracker_path]
    for delegated_task in descendant_tasks(delegated_tracker.top_level_tasks):
        if not delegated_task.checked:
            fail(
                f"{task.location}: checked parent '{task.name}' delegates to "
                f"unchecked '{delegated_task.name}' at {delegated_task.location}"
            )


def validate() -> None:
    if not ROOT_TRACKER.is_file():
        fail(f"missing canonical root tracker: {relative(ROOT_TRACKER)}")
    if not TRACKER_DIRECTORY.is_dir():
        fail(f"missing tracker directory: {relative(TRACKER_DIRECTORY)}")

    tracker_paths = [ROOT_TRACKER] + sorted(TRACKER_DIRECTORY.rglob("*.md"))
    trackers = {path.resolve(): parse_tracker(path.resolve()) for path in tracker_paths}
    root = trackers[ROOT_TRACKER.resolve()]

    actual_root_scopes = [task.name for task in root.top_level_tasks]
    if actual_root_scopes != EXPECTED_ROOT_SCOPES:
        fail(
            "root coverage divisions changed; expected:\n  - "
            + "\n  - ".join(EXPECTED_ROOT_SCOPES)
            + "\nactual:\n  - "
            + "\n  - ".join(actual_root_scopes)
        )

    canonical_references: Dict[Path, List[Task]] = {
        path.resolve(): [] for path in tracker_paths if path != ROOT_TRACKER
    }

    for tracker in trackers.values():
        validate_markdown_links(tracker, trackers)
        for task in tracker.all_tasks:
            tracker_links = TRACKER_LINK_PATTERN.findall(task.description)
            if len(tracker_links) > 1:
                fail(f"{task.location}: a task may delegate to only one tracker")
            if not tracker_links:
                continue
            if task.children:
                fail(
                    f"{task.location}: use inline children or a tracker file, not both"
                )
            target_path, fragment = resolve_local_link(tracker.path, tracker_links[0])
            if fragment:
                fail(f"{task.location}: canonical tracker links must name a file")
            try:
                target_path.relative_to(TRACKER_DIRECTORY.resolve())
            except ValueError:
                fail(
                    f"{task.location}: delegated tracker must live under "
                    f"{relative(TRACKER_DIRECTORY)}"
                )
            if target_path not in canonical_references:
                fail(f"{task.location}: delegated tracker is missing: {relative(target_path)}")
            task.tracker_path = target_path
            canonical_references[target_path].append(task)

    for tracker_path, parents in canonical_references.items():
        if len(parents) != 1:
            fail(
                f"{relative(tracker_path)}: expected exactly one canonical parent; "
                f"found {len(parents)}"
            )
        parent_task = parents[0]
        tracker = trackers[tracker_path]
        parent_matches = PARENT_PATTERN.findall(tracker.text)
        if len(parent_matches) != 1:
            fail(f"{relative(tracker_path)}: expected exactly one 'Parent:' link")
        declared_parent, fragment = resolve_local_link(tracker_path, parent_matches[0])
        if fragment or declared_parent != parent_task.source_path:
            fail(
                f"{relative(tracker_path)}: Parent link must point to canonical parent "
                f"{relative(parent_task.source_path)}"
            )

    def visit(path: Path, active: Set[Path], visited: Set[Path]) -> None:
        if path in active:
            fail(f"{relative(path)}: tracker delegation cycle detected")
        if path in visited:
            return
        active.add(path)
        for task in trackers[path].all_tasks:
            if task.tracker_path is not None:
                visit(task.tracker_path, active, visited)
        active.remove(path)
        visited.add(path)

    visited_files: Set[Path] = set()
    visit(ROOT_TRACKER.resolve(), set(), visited_files)
    if visited_files != set(trackers):
        unreachable = sorted(relative(path) for path in set(trackers) - visited_files)
        fail("orphan tracker files:\n  - " + "\n  - ".join(unreachable))

    for tracker in trackers.values():
        for task in tracker.all_tasks:
            validate_checked_rollup(task, trackers)

    total_tasks = sum(len(tracker.all_tasks) for tracker in trackers.values())
    print(
        f"TRACKER_STRUCTURE_PASS roots={len(root.top_level_tasks)} "
        f"trackers={len(trackers) - 1} tasks={total_tasks}"
    )


if __name__ == "__main__":
    try:
        validate()
    except (OSError, UnicodeError, TrackerError) as error:
        print(f"TRACKER_STRUCTURE_FAIL: {error}", file=sys.stderr)
        sys.exit(1)
