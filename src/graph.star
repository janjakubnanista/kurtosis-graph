def create():
    __self_ref = [None]
    __items_by_id = {}

    def __self():
        return __self_ref[0]

    # Adds an item to the graph.
    #
    # This function will fail if the item already exists in the graph,
    # or if the item is not valid.
    #
    # It will return the graph itself so that it can be chained.
    def add(*items):
        for item in items:
            _assert_item(item)

            if __items_by_id.get(item.id):
                fail(
                    "graph: Failed to add item {}: item with the same ID already exists".format(
                        item.id
                    )
                )

            __items_by_id[item.id] = item

        return __self()

    # Updates an item in the graph.
    #
    # This is useful for inserting launch steps into the graph
    # after the item has been added by changing the dependencies of the item.
    #
    # This function will fail if the item does not exist in the graph,
    # or if the updater is not a function, or if the updater changes the ID of the item.
    #
    # It will return the graph itself so that it can be chained.
    def update(id, updater):
        if id not in __items_by_id:
            fail("graph: Failed to update item {}: item does not exist".format(id))

        # We rigorously ensure that all is well because the errors from here would not very readable
        type_of_updater = type(updater)
        if type_of_updater != "function":
            fail(
                "graph: Failed to update item {}: expected 'updater' to be of type function but 'updater' is of type {}".format(
                    id, type_of_updater
                )
            )

        item = __items_by_id[id]
        updated_item = _assert_item(updater(item=item))

        if updated_item.id != item.id:
            fail(
                "graph: Failed to update item {}: updater changed the ID from {} to {}".format(
                    id, item.id, updated_item.id
                )
            )

        __items_by_id[id] = updated_item

        return __self()

    # Returns all the items in the graph in an unspecified order
    def items():
        return __items_by_id.values()

    # This function returns the items in the order they should be launched
    # based on their dependencies.
    #
    # It will try to preserve the order in which the items were added,
    # only reordering them if necessary to satisfy the dependencies.
    #
    # If there are any cycles in the dependencies, it will fail.
    # If there are any missing dependencies, it will also fail.
    def sequence():
        # First we check whether we have all the items
        all_dependency_ids = [
            dependency
            for item in __items_by_id.values()
            for dependency in item.dependencies
        ]

        # Now check we have all of them
        missing_dependency_ids = [
            id for id in all_dependency_ids if id not in __items_by_id
        ]
        if missing_dependency_ids:
            fail(
                "Failed to launch: Missing items {}".format(
                    ",".join(missing_dependency_ids)
                )
            )

        # Now we can order the items
        remaining_items = __items_by_id.values()
        ordered_items = []
        num_items = len(remaining_items)

        # Luckily for us our stack-based algo to order the graph
        # has an upper limit of iterations - in every iteration we need to add at least one item to the ordered items,
        # so the number of iterations is at most the number of items in the graph.
        for iteration in range(num_items):
            num_remaining_items = len(remaining_items)
            new_remaining_items = []

            # We store the IDs of the already ordered items for easy lookups
            ordered_item_ids = [item.id for item in ordered_items]

            for index in range(num_remaining_items):
                # We grab a remaining item
                item = remaining_items[index]

                # Now we check whether its dependencies are already in the ordered items
                missing_item_dependencies = [
                    id for id in item.dependencies if id not in ordered_item_ids
                ]

                # If the items has missing dependencies, we cannot add it yet
                if missing_item_dependencies:
                    new_remaining_items.append(item)
                else:
                    # If we are here, it means that all the dependencies of the item are already in the ordered items
                    # and we can add it to the ordered items
                    ordered_items.append(item)
                    ordered_item_ids.append(item.id)

            remaining_items = new_remaining_items

            # If the number of remaining items did not change,
            # it means that we did not add any items in this iteration
            # and we are stuck in a cycle.
            if len(new_remaining_items) == num_remaining_items:
                break

        if len(remaining_items) > 0:
            kurtosistest.debug("remaining items: {}".format(",".join([item.id for item in remaining_items])))
            kurtosistest.debug("ordered items: {}".format(",".join([item.id for item in ordered_items])))

            # TODO Better error message
            fail(
                "Cannot create launch sequence: Cycle detected in the graph. Remaining items: {}".format(
                    ",".join([item.id for item in remaining_items])
                )
            )

        return ordered_items

    __self_ref[0] = struct(
        add=add,
        update=update,
        launch=lambda plan: _launch(plan, __self()),
        items=items,
        sequence=sequence,
    )

    return __self()


# Launches a graph by executing each item in the order determined by the graph.
def _launch(plan, graph):
    items = graph.sequence()
    launched = {}

    for item in items:
        missing_dependencies = [id for id in item.dependencies if id not in launched]
        if missing_dependencies:
            fail(
                "graph: Launch error: Missing dependencies {} for item {}".format(
                    ",".join(missing_dependencies),
                    item.id,
                )
            )

        # We will always only pass the explicitly defined dependencies
        item_dependencies = {id: launched[id] for id in item.dependencies}

        launched[item.id] = item.launch(plan=plan, dependencies=item_dependencies)

    return launched


def item(id, launch, dependencies=[]):
    return _assert_item(
        struct(
            id=id,
            launch=launch,
            dependencies=dependencies,
        )
    )


def _lowest_desired_index(item, items):
    items_without_item = list(items)
    items_without_item.remove(item)

    for index in range(len(items)):
        previous_items = items_without_item[:index]
        previous_ids = [i.id for i in previous_items]

        missing_dependencies = [
            id for id in item.dependencies if id not in previous_ids
        ]

        if not missing_dependencies:
            return index


def _assert_item(item):
    type_of_item = type(item)
    if type_of_item != "struct":
        fail(
            "graph: Expected an item to be a struct, got {} of type {}".format(
                item, type_of_item
            )
        )

    if not hasattr(item, "id"):
        fail(
            "graph: Expected an item to have a property 'id', got {}".format(
                item, type_of_item
            )
        )

    type_of_id = type(item.id)
    if type_of_id != "string":
        fail(
            "graph: Expected an item to have an 'id' of type string but 'id' is of type {}".format(
                type_of_id
            )
        )

    if not hasattr(item, "dependencies"):
        fail(
            "graph: Expected an item to have a property 'dependencies', got {}".format(
                item, type_of_item
            )
        )

    type_of_dependencies = type(item.dependencies)
    if type_of_dependencies != "list":
        fail(
            "graph: Expected an item to have a 'dependencies' property of type list but 'dependencies' is of type {}".format(
                type_of_dependencies
            )
        )

    mistyped_dependencies = [d for d in item.dependencies if type(d) != "string"]
    if mistyped_dependencies:
        fail(
            "graph: Expected an item to have a 'dependencies' property of type list of strings but 'dependencies' contains {}".format(
                ", ".join(
                    ["{} of type {}".format(d, type(d)) for d in mistyped_dependencies]
                )
            )
        )

    has_self_as_dependency = item.id in item.dependencies
    if has_self_as_dependency:
        fail("graph: Item {} specifies itself as its dependency".format(item.id))

    if not hasattr(item, "launch"):
        fail(
            "graph: Expected an item to have a property 'launch', got {}".format(
                item, type_of_item
            )
        )

    type_of_launch = type(item.launch)
    if type_of_launch != "function":
        fail(
            "graph: Expected an item to have a 'launch' property of type function but 'launch' is of type {}".format(
                type_of_launch
            )
        )

    return item
