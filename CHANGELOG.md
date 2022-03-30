# Unreleased

- Fix deprecated uses of Redis#pipelined #357
- Add docs for running multi-sidekiq configurations #362
- Prevent sidekiq_options from overriding ActiveJob queue settings #367
- Highlight disabled jobs #369
- Require redis 4.2.0 #370
- Fixes redis deprecation warning regarding `exists` #370