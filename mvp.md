Claude client MVP.

This is an MVP for the Claude client. It provides the following API:

- Llm.Session.new/1 - creates a new session with a Claude server. It takes one optional
  argument, which is the server instructions.
- LLm.Session.send/2 - sends a message to the Claude server, and receives a response.
- Llm.Session.messages/1 - get a full list of messages sent and received during the
  session.
