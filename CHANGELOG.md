# Changelog

## [0.3.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.2.6...action_mcp/v0.3.0) (2025-03-13)


### Bug Fixes

* add resources handler to not crash for clients that don't respect capabilties ([bb854ad](https://github.com/seuros/action_mcp/commit/bb854ad5f3e64643aa5d5c4168c403f7f1634854))


### Code Refactoring

* move mcp class into mcp folder. ([3bad311](https://github.com/seuros/action_mcp/commit/3bad3116737f7754acb23f5a7c3e7bdb6b87e75a))

## [0.2.6](https://github.com/seuros/action_mcp/compare/action_mcp/v0.2.5...action_mcp/v0.2.6) (2025-03-12)


### Bug Fixes

* add db folder ([732c3e5](https://github.com/seuros/action_mcp/commit/732c3e5dadfd2dfe6e3dbafec9ec52fc9581b235))

## [0.2.5](https://github.com/seuros/action_mcp/compare/action_mcp/v0.2.4...action_mcp/v0.2.5) (2025-03-12)


### Features

* add enum to prompts ([7e28330](https://github.com/seuros/action_mcp/commit/7e2833000248ff4c82da41b974764af57ccd337a))
* Add Tables to track sessions and messages for future logging. ([cda6c6e](https://github.com/seuros/action_mcp/commit/cda6c6eeab5b74406e3f0cd95eecc41fc32719e7))


### Bug Fixes

* fixed redis adapter support ([e65157d](https://github.com/seuros/action_mcp/commit/e65157da0c6275c61dc4ab1cc5ab27d45484a793))
* removed timeout handling in TransportHandler ([e65157d](https://github.com/seuros/action_mcp/commit/e65157da0c6275c61dc4ab1cc5ab27d45484a793))

## [0.2.4](https://github.com/seuros/action_mcp/compare/action_mcp/v0.2.3...action_mcp/v0.2.4) (2025-03-11)


### Bug Fixes

* add missing folder to the gemspec ([f2282b9](https://github.com/seuros/action_mcp/commit/f2282b954a3a55bb7df041ca6408251a184958cb))

## [0.2.3](https://github.com/seuros/action_mcp/compare/action_mcp-v0.2.3...action_mcp/v0.2.3) (2025-03-11)


### Features

* add configuration class ([f363e8a](https://github.com/seuros/action_mcp/commit/f363e8af7e16a3d956f471188205cf8de10d2210))
* Add generators ([d146401](https://github.com/seuros/action_mcp/commit/d146401f7df5e6c646852c144c5008722f4381b1))
* extracted code from mcpangea ([3a9aad8](https://github.com/seuros/action_mcp/commit/3a9aad8e4d829c3304b12fe54b0cd4ef6cdc917b))
* Leverage action cable for inter process communicaiton ([f4e33ad](https://github.com/seuros/action_mcp/commit/f4e33ad37ef0104a76d4fc03c9e037da4288d3ef))


### Bug Fixes

* autoload ResourcesBank ([076b174](https://github.com/seuros/action_mcp/commit/076b17419ae5e90ec82877ce193a4c8b065a7e72))
* extract gem_version ([bcd72a2](https://github.com/seuros/action_mcp/commit/bcd72a26d789a44f8b4443d9ff9036f330da659e))
* release please ([cc9f243](https://github.com/seuros/action_mcp/commit/cc9f243d36dac61f67534674e90f86accf8c583e))
* remove resources handling, the implementation i had was custom made for my usage. We need more generic one. ([a7b4129](https://github.com/seuros/action_mcp/commit/a7b4129f8e2fb8a32e5d9845837b94c9525e3124))
* use multi_json ([929ef1c](https://github.com/seuros/action_mcp/commit/929ef1caf04b518c8bc69f6342822d5c77e4f001))

## [0.2.3](https://github.com/seuros/action_mcp/compare/v0.2.0...v0.2.3) (2025-03-11)


### Features

* extracted code from mcpangea ([3a9aad8](https://github.com/seuros/action_mcp/commit/3a9aad8e4d829c3304b12fe54b0cd4ef6cdc917b))
* Leverage action cable for inter process communicaiton ([f4e33ad](https://github.com/seuros/action_mcp/commit/f4e33ad37ef0104a76d4fc03c9e037da4288d3ef))


### Bug Fixes

* release please ([cc9f243](https://github.com/seuros/action_mcp/commit/cc9f243d36dac61f67534674e90f86accf8c583e))
* remove resources handling, the implementation i had was custom made for my usage. We need more generic one. ([a7b4129](https://github.com/seuros/action_mcp/commit/a7b4129f8e2fb8a32e5d9845837b94c9525e3124))
