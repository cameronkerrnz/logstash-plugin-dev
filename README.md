# logstash-plugin-dev
Logstash plugin development container for (J)Ruby or Java plugins

---

Docker Hub: cameronkerrnz/logstash-plugin-dev

![Docker Cloud Automated build](https://img.shields.io/docker/cloud/automated/cameronkerrnz/logstash-plugin-dev)
![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/cameronkerrnz/logstash-plugin-dev)
![Docker Pulls](https://img.shields.io/docker/pulls/cameronkerrnz/logstash-plugin-dev)

---

Developing a Logstash plugin is something that provides a lot of value,
but the typical person in the community that would do so is not someone
who would do so often, and this repo is meant to streamline that process.

Logstash plugins are typically written in Ruby (and run in JRuby). In
recent version of Logstash you can have plugins that are also pure Java,
which means less things to learn.

Logstash development requires dependencies such as JRuby, Java, Gradle...
and there are version dependencies to navigate.

I wanted a container image that has all the development tools I needed
all set up and ready to go for a particular minor release of Logstash,
and resembles the environment that the official Elastic logstash
container uses.

## Windows users

While I'm generally a Linux guy on the backend, I'm doing all this on Windows, and while I use tools like Chocolatey to keep my environment in good working order, I don't want to pollute my environment with various different software stacks; that stuff should be encapsulated away.

The only dependencies you should need for this on Windows is Docker Desktop, git, and Visual Studio Code. These are soft dependencies that are useful if you want to use this using Visual Studio Code.

**NOTE**: If you are using Docker Desktop on Windows 10 Enterprise 20.04, you will have the option to use Windows Services for Linux version 2 (WSL 2). I can only recommend **not using WSL2** at this time, particularly if you are supporting environments that run earlier versions of Glibc or the kernel. As as example, anything on centos:6 or earlier will fail to start; and tools such as Ansible experience transient failures.

This is a work-in-progress. I plan to have a branch or tag for each minor
version, such that there will be a Docker Hub image at the likes of:

## Line endings

**WARNING**. As we will be bind-mounting files into a Docker container, it is *very important* that you configure Git and your editor to keep the line endings as Unix-style LF, and not CRLF.

You may like to place a `.editorconfig` in your plugin's repository, which will [instruct editors about editor settings](https://editorconfig.org/) Example:

    end_of_line = lf
    indent_size = 4
    indent_style = space
    insert_final_newline = true
    tab_width = 4

You can also set git's policy on your local repository (I'm not going to assume you want to set this globally). Run this within the git repositories you will use for this:

    git config --local auto.crlf false


## Ruby plugin

With Logstash 7.8, you can use the `logstash-plugin generate` command. You'll find that tool in this container. Or maybe you're forking an existing plugin.

Start with the documentation under [Contributing to Logstash](https://www.elastic.co/guide/en/logstash/current/contributing-to-logstash.html)

You will want to run `logstash-plugin` from within the container, but bind-mount a place in which to generate the output.

Let's say you want to create a new filter plugin called `logstash-filter-coolstuff` in your current directory. We shall create a new plugin in a directory `logstash-filter-coolstuff` and then we'll initialise that as a Git repository and add the little bit of magic for a dev container.

    docker run --rm -it -v ${PWD}:/work cameronkerrnz/logstash-plugin-dev:latest

When the container starts, you will have a shell; you can run logstash-plugin from there:

    cd /work
    /src/logstash/bin/logstash-plugin generate --type filter --name coolstuff

Now you can exit that container.

Initialise the logstash-filter-coolstuff directory as a Git repo; this is important for Dev Containers to work it seems.

Proceed to [Using a Dev Container with Visual Studio Code](#using-a-dev-container-with-visual-studio-code)

## Java plugin

Start with the documentation under [Contributing a Java Plugin](https://www.elastic.co/guide/en/logstash/current/contributing-java-plugin.html)

You'll want to remove the .git directory from the repository you cloned and initialise it as a new Git repository.

Proceed to [Using a Dev Container with Visual Studio Code](#using-a-dev-container-with-visual-studio-code)

## Using a Dev Container with Visual Studio Code

This is seriously cool, and is what developing _should_ feel like. You can think of this as being similar to having a Vagrant VM as your development environment, but for Docker... but wait, there's more! If you were using Vagrant, then your code that are running (or wanting to run in a debugger) is not available locally; its on a remote machine (a VM on your workstation, but still a remote machine).

And what about features such as intelligent code completion, and tool support for linting, refactoring etc. How is a local IDE meant to offer such useful functionality when the likes of all your modules are not available locally? That's where [Dev Containers](https://code.visualstudio.com/docs/remote/containers) come into play.

Within Visual Studio Code, ensure you have the 'Remote - Containers' extension installed.

Open your new plugin's repository (File > Open Folder...) with Visual Studio Code. It will need to be a Git repository (CHECKME)

In the bottom-left corner there is a green icon that looks a bit like '><'. Click that, or use the command pallette, and select:

Remote-Containers: Add Development Container Configuration Files...

As this isn't an official Dev-Containers repository, use 'Existing Dockerfile', which you'll find if you 'Show all'. You'll find the following will be created in the root of your repository.

    .devcontainer/
        devcontainer.json
    ...
    logstash-filter-coolstuff.gemspec etc.
    ...

We don't actually have a Dockerfile yet, but we'll create that in the next step easily enough. Edit devcontainer.json. The format is JSON with Comments. You can
edit this as you like, but I would suggest you use the following (comments removed for brevity; compare with the [devcontainer.json documentation](https://aka.ms/vscode-remote/devcontainer.json))

    {
        "name": "Logstash Plugin Development",
        "context": "..",
        "dockerFile": "Dockerfile",
        "settings": { 
            "terminal.integrated.shell.linux": "/bin/bash"
        },
        //"mounts": [ "source=${localWorkspaceFolder},target=/work,type=bind" ],
        "remoteUser": "builder"
    }

We've referenced a Dockerfile, but we don't have one yet. We could write a big long Dockerfile that builds everything that would be needed; this is what this project has done; or we could just reference this project in the FROM:

Create a file called `Dockerfile` with the following content. You can add to this whatever you like.

    FROM cameronkerrnz/logstash-plugin-dev:latest

(Later on, this should really be something like)

    FROM cameronkerrnz/logstash-plugin-dev:7.8

When you are done, use the 'Remote-Containers: Reopen in Container' command from the command-palette, or the green '><' icon at the bottom-left.

From the VS Code menu, you can use Terminal > New Terminal to get a shell on your container.

If you use the `mount` command, you'll see that your repository has been mounted for you already at /workspaces/logstash-filter-coolstuff, and this is where your terminal session will begin.

# Build and test your plugin

## Ruby plugins

The first time you build, you will need to have done some initial setup:

- edit the *.gemspec file; you'll need to edit the bits with TODO

To build, you will generally do the following:

    rake vendor   # if you have things in vendor.json
    bundle install # installs plugin dependencies
    bundle exec rspec # run the tests... although we haven't built a gem yet
    gem build logstash-filter-coolstuff.gemspec

## Java plugins

    (wip)

# TODO: Running in a debugger

(this could be awesome)