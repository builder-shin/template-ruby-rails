<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# mailers

## Purpose

Base Rails mailer scaffold. There are no concrete delivery actions in this directory.

## Key Files

| File | Description |
|------|-------------|
| [application_mailer.rb](application_mailer.rb) | ActionMailer base with from@example.com as the placeholder sender and the mailer layout. |

## For AI Agents

Configure a real sender and add concrete mail actions/templates together when introducing mail delivery. The current base does not implement registration or password-reset emails. Add mailer behavior/rendering coverage with any new delivery action; this scaffold is excluded by spec/rails_helper.rb and no dedicated mailer specs exist.

## Dependencies

ActionMailer and app/views/layouts/mailer.html.erb / mailer.text.erb.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
