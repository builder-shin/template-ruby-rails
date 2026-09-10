<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-09-11 | Updated: 2026-09-11 -->

# layouts

## Purpose

Scaffold HTML page shell and email layouts. ApplicationMailer selects the mailer layout; API controller responses do not automatically use the HTML application shell.

## Key Files

| File | Description |
|------|-------------|
| [application.html.erb](application.html.erb) | Page title/head/body yields, CSRF/CSP tags, viewport/PWA/icon metadata, and application stylesheet inclusion. |
| [mailer.html.erb](mailer.html.erb) | HTML email shell with UTF-8 metadata and yielded message content. |
| [mailer.text.erb](mailer.text.erb) | Plain-text email body yield. |

## For AI Agents

Preserve content_for/yield slots when extending the page shell and check whether routes actually serve linked resources. The current application layout links /manifest.json although config/routes.rb does not expose it. Keep email styling compatible with the existing inline-style guidance and check both HTML and plain-text output when adding mail actions.

## Testing Requirements

No dedicated layout/view specs exist. Render and inspect affected HTML/email output when these layouts become part of a concrete feature, and test the controller/mailer that selects them.

## Dependencies

Rails ERB/Action View helpers, app/assets/stylesheets/application.css, ApplicationMailer, and /icon.png /icon.svg paths.

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
