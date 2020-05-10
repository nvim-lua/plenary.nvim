local s = require('say')

s:set_namespace('de')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', 'Noch nicht erledigt')
s:set('output.failure', 'Fehlgeschlagen')
s:set('output.success', 'Erfolgreich')

s:set('output.pending_plural', 'übersprungen')
s:set('output.failure_plural', 'fehlgeschlagen')
s:set('output.success_plural', 'erfolgreich')

s:set('output.pending_zero', 'übersprungen')
s:set('output.failure_zero', 'fehlgeschlagen')
s:set('output.success_zero', 'erfolgreich')

s:set('output.pending_single', 'übersprungen')
s:set('output.failure_single', 'fehlgeschlagen')
s:set('output.success_single', 'erfolgreich')

s:set('output.seconds', 'Sekunden')

-- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    'Du hast %d kaputte Tests.',
    'Deine Tests sind kaputt.',
    'Dein Code ist schlecht; du solltest dich schlecht fühlen.',
    'Dein Code befindet sich in der Gefahrenzone.',
    'Ein seltsames Spiel. Der einzig gewinnbringende Zug ist nicht zu testen.',
    'Meine Großmutter hat auf einem 386er bessere Tests geschrieben.',
    'Immer wenn ein Test fehlschlägt, stirbt ein kleines Kätzchen.',
    'Das fühlt sich schlecht an, oder?'
  },
  success_messages = {
    'Yeah, die Tests laufen durch.',
    'Fühlt sich gut an, oder?',
    'Großartig!',
    'Tests sind durchgelaufen, Zeit für ein Bier.',
  }
}
