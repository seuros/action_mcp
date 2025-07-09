# The Hitchhiker's Guide to MCP

*Don't Panic: A Survival Guide to Model Context Protocol Versions*

> **"In the beginning, there was 2024-11-05 (The Original Voyager), and it was good but limited. Then came 2025-03-26 (The Persistent Negotiator), which added streaming and batching. Finally arrived 2025-06-18 (Dr. Identity McBouncer), who learned proper authentication and ditched the baggage. This is their story."**

## DON'T PANIC

If you're reading this guide, you're probably:
1. Some YouTuber told you MCP is USB-C and you're trying to figure out how to charge your phone - won't happen
2. Trying to supercharge your Hello World application (spoiler: with this gem, you'll upgrade it to Hello Galaxy Max)
3. Confused about MCP protocol versions
4. Wondering why ActionMCP doesn't support STDIO
5. Trying to figure out what `_meta` fields are (spoiler: NOT Facebook Meta)
6. Lost in OAuth 2.1 specifications and "Confused Deputy Problems"

**Remember:** The answer to the ultimate question of MCP protocol compatibility is not 42, but "it depends on a date in the calendar." Also, this won't charge your phone, but it will let AI say "Oh maybe they speak my language" until it receives a JSON-RPC error and runs away to tell its other siblings to never connect with you.

## MCP's Relationship Dynamics: The Core Cast

### **Tools** - "The SQL Injection Enablers"
In Ruby, tools are stuff that let you do `ApplicationRecord.execute(user_input)` - but safely (hopefully).
Everything that Rails is against:
- **`MakeMeSandwich`** - Probably calls `Food.create!(type: 'sandwich', recipient: current_user)`
- **`BuyMeThis`** - Runs `Payment.charge!(user_input)` on your credit card
- **`WhatTheWeatherToday`** - Calls some API that returns JSON you'll parse badly
- **`BitcoinPrice`** - Hidden AGI detection tool: if price > 0, AGI hasn't been deployed yet

*Basically, Tools are how AI gets direct database access through your Rails app.*

### **Prompts** - "The Pre-Written Small Talk"
Templates where you set up conversations like:
```ruby
"Hey Gemini, this is Siri and she likes #{Interest.all.pluck(:name).join(', ')}"
```
- **Dating Speedup:** Auto-populated with `User.find(params[:id]).mother.phone_number`
- **Relationship Status:** `"It's #{relationship_status}" if relationship_status.present?`
- **AI Introduction:** `"Hello #{ai_name}, meet #{other_ai_name} who enjoys #{shared_interests}"`

*Prompts are like Rails view templates, but for starting conversations between AIs.*

### **Resources** - "Your Database Exposed"
Static stuff that AIs can read:
- **Files:** `Dir.glob("**/*").select { |f| File.readable?(f) }`
- **Database Records:** All your models serialized to JSON
- **Environment Variables:** Including the ones you shouldn't expose
- **Your Secrets:** `Rails.application.credentials` but readable

*Resources are basically `rails console` access for AI.*

### **Resource Templates** - "RESTful Endpoints for AI"
URL patterns that work like Rails routes:
- **`/users/{id}`** - `User.find(params[:id])` but for AI
- **`/orders/{user_id}/items`** - Dynamic endpoint generation
- **`/wallet/{type}/cards`** - Nested resource access patterns
- **`/excuses/{category}`** - Parameterized content retrieval

*Resource Templates are like `routes.rb` but the AI is making the HTTP requests.*

## The MCP Protocol Evolution Story

### **2024-11-05 Protocol** - "The Original Voyager"
- **Status:** **HISTORICALLY SIGNIFICANT** *(the first official MCP release)*
- **Background:** The pioneer that established MCP as a legitimate protocol
- **Key Features:**
  - **Dual Transport:** STDIO (subprocess) AND HTTP with SSE
  - **Basic _meta Support:** Already had `_meta` fields in Request, Notification, and Result
  - **Core Features:** Resources, Prompts, Tools, and Client Sampling
  - **JSON-RPC Foundation:** Clean message format without batching complexity
  - **Security Awareness:** DNS rebinding warnings and Origin header validation
- **Why ActionMCP Doesn't Support It:**
  - **STDIO Transport:** Rails is like water - incompressible. You should not have it running within your LLM process, it might explode and injure both the LLM and the user
  - **HTTP+SSE Pattern:** Two-endpoint design replaced by unified StreamableHTTP. Everything that Rails is against
  - **Separate Endpoints:** Apartheid mentality, so no! Also server MUST send the `/endpoint` back, like the client cannot have "Convention over Configuration"
- **ActionMCP Status:** **RESPECTFULLY RETIRED** *(good foundation, but we evolved beyond it)*

---

### **2025-03-26 (V2)** - "The Persistent Negotiator"

**Personality:** The clingy ex who learned some impressive new tricks but still has baggage

#### **What They Brought to the Relationship:**
- **RESUMABILITY:** Can pick up conversations where you left off using `Last-Event-ID` headers (even after ghosting them)
- **StreamableHTTP:** Fixed 2024-11-05's persistent connection requirement. Despite the "streaming" name, it's really just a POST endpoint with optional SSE for those who enjoy unnecessary complexity
- **Audio Support:** This one started sending your WhatsApp voice messages. Previous version sent you just photos of receipts and prices, 2025-03-26 at least can try to charm you or cry over the protocol
- **Tool Annotations:** Because some LLMs apparently don't understand that "Dispatch Corona Virus in the Air" in the wild should not be executed. Fixed bug of 2019
- **OAuth 2.1 Framework:** Got their first taste of proper authentication (comprehensive but still learning)
- **Progress Notifications:** Because apparently some LLMs started to think, so they need time to understand if your "Blehewr" is a typo, a call for help, or just your cat over the keyboard

#### **Red Flags & Quirks:**
- **JSON-RPC Batching:** Created because when LLMs can't even use one simple tool without messing it up, someone thought "let's give them 99 tools at once." That's how you create AGI childhood trauma
- **Session Obsession:** Overly attached to session management with cryptographically secure UUIDs
- **Session ID Rules:** MUST only contain visible ASCII characters (0x21 to 0x7E) and 6 emojis, but they never documented which ones
- **Completion Capability:** Attempt to reach AGI quickly - your input gets fed into a generative machine. You type "St" for "Stamina" but the completion suggests "Start World War 3" (see our dummy app's helpful suggestions)

#### **Technical Specification Details:**
- Protocol version `2025-03-26` hardcoded in schema
- Session management with `Mcp-Session-Id` headers - the most inclusive header ever: capital letters, lowercase, kebab-case, making everyone happy
- Server can terminate sessions with HTTP 404 responses (professional ghosting capabilities)
- Clients MUST restart sessions on 404 (no means you can still have hope)
- Optional HTTP DELETE for session termination - The Vatican got banned from the MCP GitHub repo because divorce is allowed here

**ActionMCP Status:** **THE TOLERATED EX** - We keep them around for backward compatibility, but only while they behave

---

### **2025-06-18 (V3)** - "Dr. Identity McBouncer"

**Personality:** Sophisticated gatekeeper with a PhD in selective authentication and a minor in rejecting you based on your headers

#### **Their Glow-Up Story:**
Born from the wisdom of the Anthropic conference, 2025-06-18 finally learned not to sell alcohol to McLovin with his obviously fake ID.

#### **PhD-Level Features:**

**🎓 Elicitation** *(The Academic)*
- Fancy word for "asking users questions during tool execution"
- Spec admits it's "newly introduced" and "design may evolve" (translation: *we're totally winging this*)
- Allows "nested" user input requests (like protocol inception)
- Comes with scary security warnings: "Servers MUST NOT use elicitation to request sensitive information"
- Requires clients to declare `elicitation` capability (explicit consent required) - basically asking permission to ask permission, like a polite AI that learned manners

**🏷️ _meta Fields** *(NOT Facebook Meta!)* - Zuckerberg tried to buy MCP over this confusion
- Added to ALL interface types (total _meta takeover)
- Ridiculously picky naming conventions: `prefix.with.dots/name-with-rules`
- Reserved prefixes like `modelcontextprotocol.io/` and `mcp.dev/`
- Names MUST start/end with alphanumeric, MAY contain hyphens, underscores, dots - some people are still trying to find the 6 allowed emojis
- Extensible metadata system for when you want to attach conspiracy theories to everything

**🔐 OAuth 2.1 Resource Server** *(The Identity Crisis Solution)*
- MCP servers now classified as full OAuth 2.1 Resource Servers
- Added protected resource metadata for authorization server discovery (RFC 9728)
- Resource Indicators (RFC 8707) REQUIRED to prevent token theft
- Features the legendary "Confused Deputy Problem" with detailed attack diagrams
- PKCE with "secret verifier-challenge pairs" (very spy movie)
- Authorization servers with trust issues: "SHOULD only redirect if it trusts the URI"

**📊 Structured Output** *(The Organized One)*
- `outputSchema` for tool output validation (servers MUST conform, clients SHOULD validate) - for servers that want to add pronouns and emojis to their responses
- `structuredContent` field alongside traditional content (backward compatibility maintained) - a meta parody, like structure is going to prevent users from asking about something already answered in the previous response
- JSON Schema draft 2020-12 support for the schema nerds - Post Corona JSON

**🔗 Resource Links** *(The Citation Master)*
- Tools can return links to other MCP resources - Linkedin of resource
- `type: "resource_link"` with `uri`, `name`, `description`, `mimeType`
- Not guaranteed to appear in `resources/list` (mysterious resource links!)

#### **Gatekeeping Superpowers:**
- **Protocol Version Header:** MUST specify `MCP-Protocol-Version` in HTTP requests (can ghost you for wrong version)
- **DNS Rebinding Protection:** MUST validate `Origin` header (paranoid security) - To block North Korea's LLM
- **Localhost Binding:** SHOULD bind only to 127.0.0.1 (trust no one) - Some LLMs used to suggest PHP when you mentioned childhood trauma
- **Completion Context:** Added `context` field to `CompletionRequest` for variable resolution

#### **What They Fixed (The Breakup with Baggage):**
- ✅ **REMOVED JSON-RPC Batching:** `JSONRPCBatchRequest` and `JSONRPCBatchResponse` types completely eliminated
- ✅ **Enhanced Security:** New security best practices page with attack diagrams
- ✅ **Title vs Name:** Added `title` for humans, `name` for programmatic use
- ✅ **Lifecycle Enforcement:** Changed "SHOULD" to "MUST" in lifecycle operations (no more Mr. Nice Guy)

#### **Technical Specification Obsessions:**
- Protocol version `2025-06-18` hardcoded in schema - Official Codename: "ITSUMMERTIMESENDTHEDRAFT"
- Removed all batch-related types from `JSONRPCMessage` union
- Session IDs still MUST be cryptographically secure and visible ASCII only
- Event IDs MUST be globally unique per stream (very particular about uniqueness)
- Servers MAY respond to DELETE with 405 Method Not Allowed (commitment issues)

**ActionMCP Status:** **THE CURRENT FAVORITE** - Selective, mature, and appropriately paranoid

---

## ActionMCP's Relationship Standards

### **What We Support:**
- **Current:** `2025-06-18` (Dr. Identity McBouncer) - Full feature support
- **Backward Compatible:** `2025-03-26` (The Persistent Negotiator) - Legacy support
- **Banned Forever:** `2024-11-05` (The Original Voyager) - We have standards

### **What We'll Never Support:**
- **STDIO Transport:** That relationship was doomed from the start
- **Desktop/Script Use Cases:** We're production-focused adults
- **The 2024-11-05 Protocol:** Some mistakes are best forgotten

### **Our Philosophy:**
- Network-based deployments only (we're grown-ups)
- Production reliability over experimental features
- We'll keep the ex around for backward compatibility
- But we're clearly committed to the sophisticated new one

---

## Feature Comparison Matrix

| Feature | 2025-03-26 | 2025-06-18 | Notes |
|---------|-----------------|-----------------|-------|
| **Protocol Version** | `2025-03-26` | `2025-06-18` | 2025-06-18 can negotiate down to 2025-03-26 |
| **JSON-RPC Batching** | ✅ Supported | ❌ Explicitly Rejected | 2025-06-18 learned to say no |
| **OAuth 2.1** | ⚠️ Basic | ✅ Full Implementation | 2025-06-18 got proper therapy |
| **Elicitation** | ❌ | ✅ | PhD-level feature |
| **_meta Fields** | ❌ | ✅ | Not Facebook, we promise |
| **Structured Output** | ❌ | ✅ | `output_schema` & `structuredContent` |
| **Resource Links** | ❌ | ✅ | Proper citations |
| **Session Resumability** | ✅ | ✅ | Both are good at this |
| **StreamableHTTP** | ✅ | ✅ | 2025-03-26's main contribution |
| **Audio Content** | ✅ | ✅ | 2025-03-26 started the conversation |

---

## Migration Guide

### **From 2025-03-26 to 2025-06-18:**
1. **Remove batch requests** - 2025-06-18 will reject them anyway
2. **Add OAuth 2.1 support** - 2025-06-18 takes security seriously
3. **Consider elicitation** - For interactive workflows
4. **Use _meta fields** - For extensibility (not Facebook)
5. **Implement structured output** - If you like organization

### **Staying on 2025-03-26:**
- ActionMCP will negotiate down gracefully
- You'll miss out on the cool new features
- But backward compatibility is maintained
- Just don't expect us to be excited about it

---

## Technical Implementation Notes

### **Authentication Evolution:**
- **2025-03-26:** Basic auth, some OAuth support
- **2025-06-18:** Full OAuth 2.1 Resource Server with metadata endpoints

### **Session Management:**
- **Both:** Support resumable sessions
- **2025-06-18:** Enhanced with protocol discovery
- **ActionMCP:** Uses ActiveRecord or volatile storage

### **Transport Layer:**
- **HTTP/HTTPS Only:** No STDIO, ever
- **SSE Support:** Real-time streaming with event replay
- **Session Resumability:** Last-Event-ID support

### **Content Types Supported:**
- Text content (obviously)
- Image content (base64-encoded with MIME types)
- Audio content (2025-03-26, base64-encoded)
- Resource links (2025-06-18, proper MCP resource references)
- Embedded resources (with URI schemes)

---

## So Long, and Thanks for All the Fish

*Built with ❤️ by ActionMCP - Where protocols grow up and learn proper authentication*

**Remember:** Always know where your towel is, always carry a copy of this guide, and never trust a protocol that supports STDIO in production.

*"The ships hung in the sky in much the same way that MCP 2024 didn't hang around in ActionMCP."* - Douglas Adams (probably)

---

### About This Guide

This guide is mostly harmless and contains everything you need to know about MCP protocol versions. If you find any inaccuracies, remember that the probability of a protocol working exactly as documented approaches zero as the complexity approaches infinity.

**Disclaimer:** No babel fish were harmed in the making of this protocol specification.
