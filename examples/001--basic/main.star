_graph = import_module("github.com/janjakubnanista/kurtosis-graph/src/graph.star")


def run(plan):
    graph = _graph.create()

    # Add nginx
    graph.add(
        _graph.item(
            id="nginx",
            launch=lambda plan, dependencies: plan.print(
                "Launching Nginx with the following databses: {}".format(
                    ", ".join(dependencies["db"].keys())
                )
            ),
            dependencies=["db"],
        )
    )

    # Add a "collection" item that depends on all database items
    graph.add(
        _graph.item(
            id="db",
            launch=lambda plan, dependencies: dependencies,
            dependencies=["db.postgres", "db.mysql"],
        )
    )

    # Add a postgres database
    graph.add(
        _graph.item(
            id="db.postgres",
            launch=lambda plan, dependencies: plan.print("Launching Postgres"),
            dependencies=[],
        )
    )

    # Add a mysql database
    graph.add(
        _graph.item(
            id="db.mysql",
            launch=lambda plan, dependencies: plan.print("Launching MySQL"),
            dependencies=[],
        )
    )

    # Run the graph
    graph.launch(plan=plan)
