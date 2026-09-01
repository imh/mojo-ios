from std.runtime import initialize_runtime


trait Scored:
    def score(self) -> Int64:
        ...


@fieldwise_init
struct ScoreValue(Scored):
    var value: Int64

    def score(self) -> Int64:
        return self.value * 2


def score_through_trait[T: Scored](value: T) -> Int64:
    return value.score()


@export("mojo_ios_conformance_traits")
def mojo_ios_conformance_traits() abi("C") -> Int64:
    initialize_runtime()
    return score_through_trait(ScoreValue(value=21))
