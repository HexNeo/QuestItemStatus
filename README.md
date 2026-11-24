# QuestItemStatus

**WoW: Forever** addon. Hover any item and its tooltip lists every quest the item belongs to, with your status for each one.

Наведи на предмет — в подсказке появятся все квесты, связанные с ним, и статус каждого.

## What it shows

For each quest where the item…

| Role | Meaning |
|---|---|
| starts | the item starts the quest |
| objective | the item is a quest objective |
| required | the quest needs the item but doesn't count it as an objective |
| provided | the quest giver hands you the item |

…you get a status: **completed**, **ready to turn in**, **in log** or **not taken**. Completion is read from the game's own completed-quest history, so quests finished before you installed anything are marked correctly too.

## Commands

- `/qis <itemId>` or `/qis [item link]` — print the same list to chat.

## Requirements

- [QuestieDB](https://github.com/Questie/Questie) (installed together with Questie) — supplies the quest/item database.

## Notes

- For the first 5–10 seconds after login the quest index is still building; until then only "starts quest" entries appear.
- Quests of the other faction are listed too.
- Localized: English, Russian.

## License

MIT — see [LICENSE](LICENSE).
