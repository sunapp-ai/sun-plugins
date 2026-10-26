# SUN for Claude

Ask Claude to turn any topic into something to listen to with [SUN](https://sunapp.ai):
a narrated podcast, a guided meditation for sleep, calm or focus, a bedtime story told
in chapters, or an original song. Pick one of SUN's voices or characters, or your own
voice cloned in the SUN app, and listen as soon as the first part is ready. You can also
schedule recurring audio briefings that arrive in the SUN app.

Generating audio uses credits from your SUN account.

## Install

**Claude Code**

```bash
claude plugin marketplace add sunapp-ai/sun-plugins
claude plugin install sun@sun
```

Then run `/mcp` in a session and authenticate the `sun` server to connect your SUN
account.

**Claude (web, desktop, mobile) and Cowork**

Add the plugin from **Customize > Plugins**. The first time Claude uses SUN, it shows a
**Connect** prompt; sign in to your SUN account to continue.

## Try it

- "Make me a 20 minute podcast on the Cuban Missile Crisis"
- "Make me a 10 minute sleep meditation"
- "Read my son a bedtime story about a brave little rabbit in my own voice"
- "Write a song about my dog Max"

## What works where

|                                              | Claude Code                                              | Claude apps and Cowork                                              |
| -------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------- |
| Podcasts, meditations, stories, songs        | Yes                                                      | Yes                                                                 |
| Voices, characters, scheduled briefings      | Yes                                                      | Yes                                                                 |
| Build a podcast from a file on your computer | Yes                                                      | Not yet: generate from the topic, or upload the file in the SUN app |
| Download the audio locally                   | Yes, when the SUN CLI (`sun`) is installed and signed in | No; use the listening link                                          |

## Privacy and support

- Privacy policy: https://sunapp.ai/privacy
- Terms of service: https://sunapp.ai/terms
- Billing and credits: https://sunapp.ai/faq#billing
- Support: https://sunapp.ai/support

## License

The text and scripts in this plugin are available under the [MIT License](LICENSE).
The SUN service itself is not covered by this license.

The MIT License covers the code in this repository. It does not grant rights to use the SUN name or logo.
