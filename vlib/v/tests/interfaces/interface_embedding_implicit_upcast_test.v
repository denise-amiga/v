interface Base {
}

interface Solid {
	Base
}

struct Empty {
}

fn greet(x Base) bool {
	return x is Empty
}

fn pass_through(x Solid) Base {
	return x
}

fn test_interface_embedding_implicit_upcast() {
	solid := Solid(Empty{})
	assert greet(Empty{})
	assert greet(solid)
	assert greet(Solid(Empty{}))
	base := pass_through(solid)
	assert base is Empty
}
