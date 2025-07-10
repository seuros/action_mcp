# Maintenance Guidelines

This document outlines the maintenance and support policies for our Ruby gem. By using or contributing to this project, you agree to follow these guidelines.

## Supported Versions

- **Latest Versions Only:**
  The gem is tested against the latest versions of Ruby and Rails. We do not officially support legacy versions.

- **Head Versions:**
  Pre-release (head) versions of Ruby and Rails will be tested. Once a new release is deemed stable, the gem will be updated to support that version.

- **Legacy Versions:**
  Legacy versions will only be maintained if:
    - The underlying framework/language has not changed significantly, or
    - The gem does not require new features or adjustments introduced in newer versions.

## Bug Reporting & Feature Clarifications

- **Legacy Bugs:**
  If a bug appears in a legacy version of Rails but not in the latest version, it is considered a feature rather than a bug. We prioritize stability on the latest supported versions.

- **Custom Modifications:**
  If your project or organization uses monkey patches and an update causes issues, please do not report these as bugs—unless you can submit a Pull Request (PR) with a concrete use case. We focus on maintaining the core functionality rather than supporting edge cases created by custom modifications.

## Protocol & Feature Proposals

- **MCP Protocol Compliance:**
  The gem adheres to the MCP protocol specification. It can serve as a platform for proposing new features, leveraging Ruby and Rails' rapid prototyping capabilities.

## Code Style

- **Standardized Styling:**
  Our code follows the Rails community style guidelines to maintain consistency and readability. While there might be personal styling preferences, adhering to standardized conventions is mandatory.

## Contributing

- Contributions are welcome! Before opening a PR, please ensure your changes comply with the guidelines above and include appropriate tests and documentation.
- For any questions or further clarifications, feel free to open an issue or contact the maintainers directly.

---

*Note: These guidelines are subject to change as the project evolves. Please refer back to this document for the most current maintenance policies.*
