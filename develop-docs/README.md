# Develop Documentation

This page contains internal documentation for development.

## Auto UI Performance Class Overview

![Auto UI Performance Class Overview](./auto-ui-performance-tracking.svg)

## Generating Diagrams

The diagrams are created with [PlantUml](http://plantuml.com). The advantage of PlantUml
over other diagram tools is that you describe the diagrams with text, and you don't have
to worry about UML and layout, which can be time-consuming for changes. Furthermore, the
diagrams can be stored in git.

With [Visual Studio Code](https://code.visualstudio.com/) and the
[PlantUml Plugin](https://marketplace.visualstudio.com/items?itemName=jebbs.plantuml#user-content-use-plantuml-server-as-render)
you can create diagrams, view them and export them. If you don't want to use Visual Studio Code,
there are many [alternatives](http://plantuml.com/running).

For learning the syntax and quickly playing around you can check out [Plant Text](https://www.planttext.com/).

### Visual Studio Code Setup

Visual Studio Code needs a rendering engine for PlantUml. We recommend using the following Docker image:

```sh
docker run -d -p 8080:8080 plantuml/plantuml-server:jetty
```

To ensure the rendering server is running properly, visit with `localhost:8080`.

Finally, you have to configure the rendering server in Visual Studio Code. For this, open the settings of Visual Studio Code. Choose `Extensions > PlantUML configuration`. Click on `Edit in settings.json`. Then paste the following into the config:

```json
{
  "plantuml.server": "http://localhost:8080",
  "plantuml.render": "PlantUMLServer"
}
```

Save the settings and you should be able to render a diagram.

You can find the official guide here: [configure a rendering server](https://marketplace.visualstudio.com/items?itemName=jebbs.plantuml#user-content-use-plantuml-server-as-render).
