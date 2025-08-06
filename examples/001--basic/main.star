_graph = import_module("/src/graph.star")

def run(plan):
    graph = _graph.create()

    _add_databases(plan=plan, graph=graph)

    # Run the graph
    graph.launch(plan=plan)

def _add_databases(plan, graph):
    graph.add(_graph.item(
        id="db.postgres",
        launch=lambda plan, dependencies: plan.print("Launching Postgres"),
        dependencies=[],
    ))

    graph.add(_graph.item(
        id="db.mysql",
        launch=lambda plan, dependencies: plan.print("Launching MySQL"),
        dependencies=[],
    ))

    graph.add(_graph.item(
        id="db",
        launch=lambda plan, dependencies: plan.print("Launched all databases: {}".format(
            ",".join(dependencies.keys())
        )),
        dependencies=["db.postgres", "db.mysql"],
    ))