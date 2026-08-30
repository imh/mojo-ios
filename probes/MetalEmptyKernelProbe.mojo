from std.gpu import global_idx


@export("mojo_metal_empty_kernel")
def mojo_metal_empty_kernel():
    _ = global_idx.x
