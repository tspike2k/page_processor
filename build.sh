#!/bin/bash
dmd src/main.d -g -Isrc -of=bin -i -version=testing
rm *.o