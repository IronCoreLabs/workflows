val Http4sVersion = "0.23.18"
val CirceVersion = "0.14.3"
val MunitVersion = "0.7.29"
val LogbackVersion = "1.2.11"
val MunitCatsEffectVersion = "1.0.7"

lazy val root = (project in file("."))
  .settings(
    organization := "com.example",
    name := "test-project",
    version := "0.0.1-SNAPSHOT",
    scalaVersion := "2.13.15",
    libraryDependencies ++= Seq(
      "org.http4s"       %% "http4s-ember-server" % Http4sVersion,
      "org.http4s"       %% "http4s-ember-client" % Http4sVersion,
      "org.http4s"       %% "http4s-circe"        % Http4sVersion,
      "org.http4s"       %% "http4s-dsl"          % Http4sVersion,
      "io.circe"         %% "circe-generic"       % CirceVersion,
      "com.ironcorelabs" %% "http4s-contrib"      % "0.7.0",
      "org.scalameta"    %% "munit"               % MunitVersion           % Test,
      "org.typelevel"    %% "munit-cats-effect-3" % MunitCatsEffectVersion % Test,
      "ch.qos.logback"   %  "logback-classic"     % LogbackVersion         % Runtime,
    ),
    addCompilerPlugin("org.typelevel" %% "kind-projector"     % "0.13.2" cross CrossVersion.full),
    addCompilerPlugin("com.olegpy"    %% "better-monadic-for" % "0.3.1"),
    testFrameworks += new TestFramework("munit.Framework")
  )