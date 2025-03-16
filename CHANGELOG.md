# Changelog

## [0.15.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.14.0...action_mcp/v0.15.0) (2025-03-16)


### Features

* refactor order and product fetching methods to use find_by; add SamplingRequest class for managing AI interactions ([769fb90](https://github.com/seuros/action_mcp/commit/769fb90e3301e69901ef82cab0923f5a7ddc2f0c))
* rename fetch method to resolve in resource templates for clarity; update related references ([37d1a6d](https://github.com/seuros/action_mcp/commit/37d1a6d13388c92c9f69e436670245e3f12d0ecb))

## [0.14.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.13.0...action_mcp/v0.14.0) (2025-03-16)


### Features

* enhance test coverage for tools and prompts; update execution methods and assertions for consistency ([e2b0937](https://github.com/seuros/action_mcp/commit/e2b0937a4be8e75b4a0b278846fd29989ef1f7e2))

## [0.13.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.12.0...action_mcp/v0.13.0) (2025-03-16)


### Features

* add notifications module for client resource updates and logging; refactor transport handler to include notifications ([dd6a8e3](https://github.com/seuros/action_mcp/commit/dd6a8e363ccf97705d42a005e84ab3aadae8aec4))

## [0.12.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.11.0...action_mcp/v0.12.0) (2025-03-16)


### Features

* add is_error attribute to PromptResponse class; update JSON-RPC handler to improve error response handling ([1871060](https://github.com/seuros/action_mcp/commit/18710605d7a7723704c13931e2054c54984f3114))

## [0.11.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.10.0...action_mcp/v0.11.0) (2025-03-16)


### Features

* improve error handling and response structure in tools and prompts; add tests for tool and prompt calls ([b6e23e9](https://github.com/seuros/action_mcp/commit/b6e23e99cc89f4560698a54a2e97693e650e3047))

## [0.10.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.9.0...action_mcp/v0.10.0) (2025-03-16)


### Features

* add PromptResponse and ToolResponse classes with enhanced functionality; include tests for message handling and response structure ([c9e2976](https://github.com/seuros/action_mcp/commit/c9e2976537b5a5f9b3db597534be867148344196))
* enhance error handling in prompts; update response structure for better error reporting and validation feedback ([46d9bae](https://github.com/seuros/action_mcp/commit/46d9bae8600f6ecd64a79617ba01ffea596ddb41))

## [0.9.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.8.0...action_mcp/v0.9.0) (2025-03-16)


### Features

* add ActionMCP session management with subscriptions and resources; include database migrations and model definitions ([f80cab9](https://github.com/seuros/action_mcp/commit/f80cab9ca449f883e1b3a2d09c7c3e8f32636597))
* implement ToolResponse class for managing tool execution results and error handling; refactor render method in tools ([617bcd6](https://github.com/seuros/action_mcp/commit/617bcd69e4fec9bc764eb40325bf0740985f3172))
* rename 'call' method to 'perform' in prompt classes; add CarbonFootprintAssessmentPrompt and GreetingPrompt classes with detailed user interactions ([38f4ed1](https://github.com/seuros/action_mcp/commit/38f4ed18c9f8d2cbc626bf97ed8bad27fa1b9632))

## [0.8.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.7.2...action_mcp/v0.8.0) (2025-03-15)


### Features

* add caching mechanism ([22fbbc0](https://github.com/seuros/action_mcp/commit/22fbbc0a660f928cbcd99cca198cdfa4796bf219))
* update cable configuration and add solid_cable support; enhance session handling and logging ([d29375f](https://github.com/seuros/action_mcp/commit/d29375fe501538c584c66c3bfa9ce7262b5c7147))

## [0.7.2](https://github.com/seuros/action_mcp/compare/action_mcp/v0.7.1...action_mcp/v0.7.2) (2025-03-15)


### Bug Fixes

* allow nil values in numericality validation ([3a5cde2](https://github.com/seuros/action_mcp/commit/3a5cde2694a5233608099bcddd62463f5e1868ed))
* clear registered templates before configuration and handle name conflicts ([b416b65](https://github.com/seuros/action_mcp/commit/b416b65b2989c76483b50fdc94d8368e63270685))

## [0.7.1](https://github.com/seuros/action_mcp/compare/action_mcp/v0.7.0...action_mcp/v0.7.1) (2025-03-15)


### Bug Fixes

* fix error handling and optimize SSE listener initialization ([dcf5048](https://github.com/seuros/action_mcp/commit/dcf50484e87c5b3b7c1508307ed9bbef6e5e37e1))

## [0.7.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.6.0...action_mcp/v0.7.0) (2025-03-15)


### Features

* enhance rendering and URI template validation in ActionMCP ([7b02872](https://github.com/seuros/action_mcp/commit/7b02872ee31ceb83f2e28b894b425eb355c05e91))
* update resource templates and enhance URI parsing functionality ([8937daf](https://github.com/seuros/action_mcp/commit/8937dafecf71faee6e1126684685174e1a103b52))


### Bug Fixes

* disable ping for now, it badly implemented. ([7b02872](https://github.com/seuros/action_mcp/commit/7b02872ee31ceb83f2e28b894b425eb355c05e91))

## [0.6.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.5.1...action_mcp/v0.6.0) (2025-03-15)


### Features

* add is_ping and ping_acknowledged fields to session messages ([42e3833](https://github.com/seuros/action_mcp/commit/42e383378a5fd75102733734740686e57a15443b))

## [0.5.1](https://github.com/seuros/action_mcp/compare/action_mcp/v0.5.0...action_mcp/v0.5.1) (2025-03-14)


### Bug Fixes

* add test to inheritance ([30a5303](https://github.com/seuros/action_mcp/commit/30a5303335426e58fc9240ee1bc5d9fd95a7b791))
* never trust autocomplete ([6cf13ad](https://github.com/seuros/action_mcp/commit/6cf13ad228b30426df47b0543cdf5be77eaeb11d))

## [0.5.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.4.0...action_mcp/v0.5.0) (2025-03-14)


### Features

* enhance ActionMCP configuration and add resource template tests ([2bd4429](https://github.com/seuros/action_mcp/commit/2bd44299deb5326f08a9e295bdbd237d4ae7155e))


### Bug Fixes

* update ResourceTemplate generator template ([e166ea6](https://github.com/seuros/action_mcp/commit/e166ea675e5a270e86c45f85104d8691b0ca00c3))

## [0.4.0](https://github.com/seuros/action_mcp/compare/action_mcp/v0.3.0...action_mcp/v0.4.0) (2025-03-14)


### Features

* add files to help Assistant build components ([cce5d34](https://github.com/seuros/action_mcp/commit/cce5d345404b7ab14abdd60fa9d53a98a461ffeb))
* add ResourceTemplate handling ([0423a55](https://github.com/seuros/action_mcp/commit/0423a5506d63a080c3a8f475f37d56ef532eb039))
* add test helper ([1262b80](https://github.com/seuros/action_mcp/commit/1262b8051ab4549bbc000b40368e88e1c4094f21))


### Bug Fixes

* add list_resources to the rake task ([08d52ed](https://github.com/seuros/action_mcp/commit/08d52ed90931451423356054efbcb168f066a898))

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
