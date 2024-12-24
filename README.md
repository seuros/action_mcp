# ActionMCP

**ActionMCP** is a Ruby gem that provides essential tooling for building Model Context Protocol (MCP) capable servers. 
It offers base classes and helpers for creating MCP applications, making it easier to integrate your Ruby/Rails application with the MCP standard. 
With ActionMCP, you can focus on your app's logic while it handles the boilerplate for MCP compliance.

## Introduction

**Model Context Protocol (MCP)** is an open protocol that standardizes how applications provide context to large language models (LLMs) ([Introduction - Model Context Protocol](https://modelcontextprotocol.io/introduction#:~:text=MCP%20is%20an%20open%20protocol,different%20data%20sources%20and%20tools)). 

Think of it as a universal interface for connecting AI assistants to external data sources and tools. 

MCP allows AI systems to plug into various resources in a consistent, secure way, enabling two-way integration between your data and AI-powered applications ([Introducing the Model Context Protocol \ Anthropic](https://www.anthropic.com/news/model-context-protocol#:~:text=The%20Model%20Context%20Protocol%20is,that%20connect%20to%20these%20servers)). 

This means an AI (like an LLM) can request information or actions from your application through a well-defined protocol, and your app can provide context or perform tasks for the AI in return.

**ActionMCP** is targeted at developers building MCP-enabled applications. 
It simplifies the process of integrating Ruby and Rails apps with the MCP standard by providing a set of base classes and an easy-to-use server interface. 

Instead of implementing MCP support from scratch, you can subclass and configure the provided **Prompt**, **Tool**, and **Resource** classes to expose your app’s functionality to LLMs. 

ActionMCP handles the underlying MCP message format and routing, so you can adhere to the open standard with minimal effort. 

In short, ActionMCP helps you build an MCP server (the component that exposes capabilities to AI) more quickly and with fewer mistakes.

## Installation

To start using ActionMCP, add it to your project:

- **Using Bundler (Rails or Ruby projects):** Add the gem to your Gemfile and run bundle install:
  
  execute:
  ```
  $ bundle add actionmcp
  ```

After installing, include the gem in your code by requiring it:

This will load the ActionMCP library so you can start defining MCP prompts, tools, and resources in your application.

## Core Components

ActionMCP provides three core abstractions to streamline MCP server development: **Prompt**, **Tool**, and **Resource**. 
These correspond to key MCP concepts and let you define what context or capabilities your server exposes to LLMs. 
Below is an overview of each component and how you might use it:

### ActionMCP::Prompt

Make Rails Say Sexy stuff 

### ActionMCP::Tool

Make Rails Do Sexy stuff and serve beer to Clients.

### ActionMCP::Resource

I dont need this for now
