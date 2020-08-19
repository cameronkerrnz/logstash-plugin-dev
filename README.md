# logstash-plugin-dev
Logstash plugin development container for (J)Ruby or Java plugins

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

This is a work-in-progress. I plan to have a branch or tag for each minor
version, such that there will be a Docker Hub image at the likes of:

cameronkerrnz/logstash-plugin-dev:7.8

