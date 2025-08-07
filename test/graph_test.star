_graph = import_module("/src/graph.star")


def _default_launch(plan, dependencies):
    return None


def _default_updater(item):
    return item


def test_util_schedule_dependency_invalid_item(plan):
    graph = _graph.create()

    # We check for a missing id
    expect.fails(
        lambda: graph.add(struct()),
        "graph: Expected an item to have a property 'id'",
    )

    # We check for a mistyped id
    expect.fails(
        lambda: graph.add(struct(id=123)),
        "graph: Expected an item to have an 'id' of type string but 'id' is of type int",
    )

    # We check for missing dependencies
    expect.fails(
        lambda: graph.add(struct(id="a", launch=_default_launch)),
        "graph: Expected an item to have a property 'dependencies'",
    )

    # We check for mistyped dependencies
    expect.fails(
        lambda: graph.add(struct(id="a", launch=_default_launch, dependencies="b")),
        "graph: Expected an item to have a 'dependencies' property of type list but 'dependencies' is of type string",
    )

    # We check for mistyped dependencies
    expect.fails(
        lambda: graph.add(
            struct(id="a", launch=_default_launch, dependencies=[123, [], {}, False])
        ),
        "graph: Expected an item to have a 'dependencies' property of type list of strings but 'dependencies' contains 123 of type int, \\[\\] of type list, \\{\\} of type dict, False of type bool",
    )

    # We check for missing launch
    expect.fails(
        lambda: graph.add(struct(id="a", dependencies=["b"])),
        "graph: Expected an item to have a property 'launch'",
    )

    # We check for mistyped launch
    expect.fails(
        lambda: graph.add(struct(id="a", launch=123, dependencies=["b"])),
        "graph: Expected an item to have a 'launch' property of type function but 'launch' is of type int",
    )


def test_util_schedule_dependency_on_self(plan):
    graph = _graph.create()

    # We check whether the item() utility function catches this
    expect.fails(
        lambda: _graph.item(id="a", launch=_default_launch, dependencies=["a"]),
        "graph: Item a specifies itself as its dependency",
    )

    # And whether the graph.add() function catches this
    expect.fails(
        lambda: graph.add(struct(id="a", launch=_default_launch, dependencies=["a"])),
        "graph: Item a specifies itself as its dependency",
    )


def test_util_schedule_add_duplicate_id(plan):
    graph = _graph.create()

    item_a = _graph.item(id="a", launch=_default_launch)
    graph.add(item_a)

    # Adding an item with the same id should fail
    expect.fails(
        lambda: graph.add(item_a),
        "graph: Failed to add item a: item with the same ID already exists",
    )


def test_util_schedule_update_missing_item(plan):
    graph = _graph.create()

    expect.fails(
        lambda: graph.update(id="a", updater=_default_updater),
        "graph: Failed to update item a: item does not exist",
    )


def test_util_schedule_update_invalid_updater(plan):
    graph = _graph.create()

    item_a = _graph.item(id="a", launch=_default_launch)
    graph.add(item_a)

    expect.fails(
        lambda: graph.update(id="a", updater=123),
        "graph: Failed to update item a: expected 'updater' to be of type function but 'updater' is of type int",
    )


def test_util_schedule_update_success(plan):
    graph = _graph.create()

    item_a = _graph.item(id="a", launch=_default_launch)
    item_b = _graph.item(id="b", launch=_default_launch, dependencies=["a"])
    item_c = _graph.item(id="c", launch=_default_launch, dependencies=["a"])

    graph.add(item_a)
    graph.add(item_b)
    graph.add(item_c)

    expect.eq(graph.sequence(), [item_a, item_b, item_c])

    updated_item_b = _graph.item(id="b", launch=_default_launch, dependencies=["c"])
    graph.update(id="b", updater=lambda item: updated_item_b)

    expect.eq(graph.sequence(), [item_a, item_c, updated_item_b])


def test_util_schedule_update_changed_id(plan):
    graph = _graph.create()

    item_a = _graph.item(id="a", launch=_default_launch)
    graph.add(item_a)

    expect.fails(
        lambda: graph.update(
            id="a", updater=lambda item: _graph.item(id="b", launch=_default_launch)
        ),
        "graph: Failed to update item a: updater changed the ID from a to b",
    )


def test_util_schedule_no_dependencies(plan):
    graph = _graph.create()

    item_a = _graph.item(id="a", launch=_default_launch)
    item_b = _graph.item(id="b", launch=_default_launch)

    graph.add(item_b)
    graph.add(item_a)

    expect.eq(graph.sequence(), [item_b, item_a])


def test_util_schedule_simple_linear_dependencies(plan):
    graph = _graph.create()

    item_a = _graph.item(id="a", launch=_default_launch)
    item_b = _graph.item(id="b", launch=_default_launch, dependencies=["a"])

    graph.add(item_b)
    graph.add(item_a)

    expect.eq(graph.sequence(), [item_a, item_b])


def test_util_schedule_reverse_order_of_addition(plan):
    graph = _graph.create()

    item_a = _graph.item(id="a", launch=_default_launch, dependencies=["b"])
    item_b = _graph.item(id="b", launch=_default_launch, dependencies=["b.1", "b.2"])
    item_b1 = _graph.item(id="b.1", launch=_default_launch)
    item_b2 = _graph.item(id="b.2", launch=_default_launch)

    graph.add(item_a)
    graph.add(item_b)
    graph.add(item_b1)
    graph.add(item_b2)

    expect.eq(graph.sequence(), [item_b1, item_b2, item_b, item_a])


def test_util_schedule_simple_simple_cycle_dependencies(plan):
    graph = _graph.create()

    item_a = _graph.item(id="a", launch=_default_launch, dependencies=["b"])
    item_b = _graph.item(id="b", launch=_default_launch, dependencies=["a"])

    graph.add(item_b)
    graph.add(item_a)

    expect.fails(
        lambda: graph.sequence(), "Cannot create launch sequence: Cycle detected in the graph: b ↔︎ a"
    )


def test_util_schedule_simple_large_cycle_dependencies(plan):
    graph = _graph.create()

    item_a = _graph.item(id="a", launch=_default_launch, dependencies=["d"])
    item_b = _graph.item(id="b", launch=_default_launch, dependencies=["a"])
    item_c = _graph.item(id="c", launch=_default_launch, dependencies=["b"])
    item_d = _graph.item(id="d", launch=_default_launch, dependencies=["a"])

    graph.add(item_b)
    graph.add(item_a)
    graph.add(item_c)
    graph.add(item_d)

    expect.fails(
        lambda: graph.sequence(), "Cannot create launch sequence: Cycle detected in the graph: b ↔︎ a ↔︎ c ↔︎ d"
    )


def test_util_schedule_simple_branching_dependencies(plan):
    graph = _graph.create()

    item_a = _graph.item(id="a", launch=_default_launch)
    item_b = _graph.item(id="b", launch=_default_launch)
    item_c1 = _graph.item(id="c1", launch=_default_launch, dependencies=["b"])
    item_c2 = _graph.item(id="c2", launch=_default_launch, dependencies=["b"])
    item_c21 = _graph.item(id="c21", launch=_default_launch, dependencies=["c2"])
    item_c22 = _graph.item(id="c22", launch=_default_launch, dependencies=["c21"])
    item_c3 = _graph.item(id="c3", launch=_default_launch, dependencies=["b"])
    item_d = _graph.item(
        id="d", launch=_default_launch, dependencies=["c1", "c22", "c3"]
    )

    graph.add(item_b)
    graph.add(item_c1)
    graph.add(item_d)
    graph.add(item_c21)
    graph.add(item_c22)
    graph.add(item_a)
    graph.add(item_c3)
    graph.add(item_c2)

    expect.eq(
        graph.sequence(),
        [item_b, item_c1, item_a, item_c3, item_c2, item_c21, item_c22, item_d],
    )


def test_util_schedule_launch_empty(plan):
    graph = _graph.create()

    # Launching an empty graph should return an empty dict
    expect.eq(graph.launch(plan), {})


def test_util_schedule_launch_simple(plan):
    graph = _graph.create()

    graph.add(
        _graph.item(
            id="a",
            launch=lambda plan, dependencies: "a launched with dependencies {}".format(
                dependencies
            ),
        )
    )
    graph.add(
        _graph.item(
            id="b",
            launch=lambda plan, dependencies: "b launched with dependencies {}".format(
                dependencies
            ),
            dependencies=["a"],
        )
    )

    expect.eq(
        graph.launch(plan),
        {
            "a": "a launched with dependencies {}",
            "b": 'b launched with dependencies {"a": "a launched with dependencies {}"}',
        },
    )


def test_util_schedule_launch_branching(plan):
    graph = _graph.create()

    graph.add(
        _graph.item(
            id="a",
            launch=lambda plan, dependencies: "a launched with dependencies {}".format(
                ",".join(dependencies.keys())
            ),
        )
    )
    graph.add(
        _graph.item(
            id="b",
            launch=lambda plan, dependencies: "b launched with dependencies {}".format(
                ",".join(dependencies.keys())
            ),
            dependencies=["a"],
        )
    )
    graph.add(
        _graph.item(
            id="c1",
            launch=lambda plan, dependencies: "c1 launched with dependencies {}".format(
                ",".join(dependencies.keys())
            ),
            dependencies=["b"],
        )
    )
    graph.add(
        _graph.item(
            id="c2",
            launch=lambda plan, dependencies: "c2 launched with dependencies {}".format(
                ",".join(dependencies.keys())
            ),
            dependencies=["b"],
        )
    )
    graph.add(
        _graph.item(
            id="d",
            launch=lambda plan, dependencies: "d launched with dependencies {}".format(
                ",".join(dependencies.keys())
            ),
            dependencies=["c1", "c2"],
        )
    )

    expect.eq(
        graph.launch(plan),
        {
            "a": "a launched with dependencies ",
            "b": "b launched with dependencies a",
            "c1": "c1 launched with dependencies b",
            "c2": "c2 launched with dependencies b",
            "d": "d launched with dependencies c1,c2",
        },
    )


def test_util_schedule_launch_no_implicit_dependencies(plan):
    graph = _graph.create()

    graph.add(
        _graph.item(
            id="a",
            launch=lambda plan, dependencies: expect.eq(dependencies, {}),
        )
    )

    graph.add(
        _graph.item(
            id="b",
            launch=lambda plan, dependencies: expect.eq(dependencies, {"a": None}),
            dependencies=["a"],
        )
    )

    graph.add(
        _graph.item(
            id="c",
            launch=lambda plan, dependencies: expect.eq(dependencies, {"b": None}),
            dependencies=["b"],
        )
    )

    expect.eq(
        graph.launch(plan),
        {
            "a": None,
            "b": None,
            "c": None,
        },
    )
