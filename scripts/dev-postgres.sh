#!/usr/bin/env bash

docker run -it --rm --name pg18-temp -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=blog -p 5432:5432 postgres:18
