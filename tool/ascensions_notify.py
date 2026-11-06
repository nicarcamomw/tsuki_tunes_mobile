"""Tells the app's keeper about Bearers at Eco level 100.

Reads ascensions/{uid} in Firestore (written by the app; see firestore.rules)
and, for each event not told yet, opens a GitHub issue assigned to the
repository owner, who gets it by email:

- reach: a Bearer reached level 100 (their name, their Eco).
- choice: they chose to become an ethereal being (with the name for their
  mask, to forge it) or to stay a Bearer.
- legend: they reached the level of the Supreme Gods. It has never happened.

Then it marks the document as told (notifiedReach, notifiedChoice,
notifiedLegend), fields the app cannot write.

Run by .github/workflows/ascensions.yml with SERVICE_ACCOUNT, GH_TOKEN,
REPO and OWNER in the environment.
"""

import json
import os
import subprocess

from google.cloud import firestore
from google.oauth2 import service_account

PROJECT = 'tsuki-tunes-web'


def issue(title: str, body: str) -> None:
    subprocess.run(
        ['gh', 'issue', 'create', '--repo', os.environ['REPO'], '--title', title,
         '--body', body, '--assignee', os.environ['OWNER']],
        check=True,
    )


def main() -> None:
    info = json.loads(os.environ['SERVICE_ACCOUNT'])
    creds = service_account.Credentials.from_service_account_info(info)
    db = firestore.Client(project=PROJECT, credentials=creds)

    for snap in db.collection('ascensions').stream():
        d = snap.to_dict() or {}
        name = d.get('name') or '(sin nombre)'
        eco = d.get('eco', 0)
        when = d.get('at')
        footer = f'\n\nCuenta: `{snap.id}`\nEco: {eco:,}\nFecha: {when}'.replace(',', '.')
        marks = {}

        if not d.get('notifiedReach'):
            issue(f'Un Portador llegó al nivel 100: {name}',
                  f'**{name}** llegó al nivel 100 de Eco. Está frente a su elección: '
                  'volverse un ser etéreo o seguir siendo Portador.' + footer)
            marks['notifiedReach'] = True

        choice = d.get('choice')
        if choice and d.get('notifiedChoice') != choice:
            if choice == 'ser':
                mask = d.get('maskName') or name
                issue(f'{name} eligió SER: forjar su máscara etérea',
                      f'**{name}** traspasó la muralla de lo lógico y se volvió un **ser etéreo**.\n\n'
                      f'Nombre para su máscara etérea: **{mask}**.\n\n'
                      'Hay que crear su máscara y otorgársela.' + footer)
            else:
                issue(f'{name} eligió NO SER',
                      f'**{name}** decidió mantener su forma de Portador. Ya no podrá volverse '
                      'un ser etéreo: queda como Portador Inconmensurable.' + footer)
            marks['notifiedChoice'] = choice

        if d.get('legend') and not d.get('notifiedLegend'):
            issue(f'NIVEL 100+: {name} alcanzó el nivel de un Dios Supremo',
                  f'**{name}** alcanzó el Eco de un Dios Supremo. Nunca había pasado. '
                  'El equilibrio se ha roto.' + footer)
            marks['notifiedLegend'] = True

        if marks:
            snap.reference.update(marks)
            print(f'{snap.id}: {", ".join(marks)}')


if __name__ == '__main__':
    main()
