#!/usr/bin/env bash

# Clear your Telegram account by deleting all your messages

from os import environ

from dotenv import load_dotenv
from pyrogram.client import Client

load_dotenv()

app = Client("clean telegram", api_id=environ["API_ID"], api_hash=environ["API_HASH"])


async def main():
    async with app:
        async for dialog in app.get_dialogs():
            async for message in app.get_chat_history(dialog.chat.id):
                if (
                    message.from_user is not None
                    and message.from_user.is_self
                    and message.text != "adios 👋"
                ):
                    print(f'Deleting "{message.text}"\n')
                    await message.delete()


app.run(main())
