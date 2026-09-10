<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# application_cable

## Purpose

ApplicationCable namespace containing empty Rails websocket base classes.

## Key Files

| File | Description |
|------|-------------|
| [channel.rb](channel.rb) | ApplicationCable::Channel inherits ActionCable::Channel::Base. |
| [connection.rb](connection.rb) | ApplicationCable::Connection inherits ActionCable::Connection::Base without identity/authentication callbacks. |

## For AI Agents

Put shared channel behavior and connection setup in the corresponding base class. Do not assume Current.user or controller Bearer authentication is established on a Cable connection. Implement identity checks with meaningful connection tests if a feature needs them.

## Testing Requirements

test/channels/application_cable/connection_test.rb contains only a commented example. Run new connection tests through bin/rails test test/channels/application_cable/connection_test.rb after completing them. spec/rails_helper.rb excludes these scaffold classes from SimpleCov.

## Dependencies

Action Cable and config/cable.yml; there are currently no domain-model dependencies in these classes.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
