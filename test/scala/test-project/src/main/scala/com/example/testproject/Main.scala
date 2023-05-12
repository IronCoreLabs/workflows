package com.example.testproject

import cats.effect.{IO, IOApp}

object Main extends IOApp.Simple {
  val run = TestprojectServer.run[IO]
}
