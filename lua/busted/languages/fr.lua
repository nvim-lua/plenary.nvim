local s = require('say')

s:set_namespace('fr')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', 'En attente')
s:set('output.failure', 'Echec')
s:set('output.success', 'Reussite')

s:set('output.pending_plural', 'en attente')
s:set('output.failure_plural', 'echecs')
s:set('output.success_plural', 'reussites')

s:set('output.pending_zero', 'en attente')
s:set('output.failure_zero', 'echec')
s:set('output.success_zero', 'reussite')

s:set('output.pending_single', 'en attente')
s:set('output.failure_single', 'echec')
s:set('output.success_single', 'reussite')

s:set('output.seconds', 'secondes')

s:set('output.no_test_files_match', 'Aucun test n\'est pourrait trouvé qui corresponde au motif de Lua: %s')

-- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    'Vous avez %d test(s) qui a/ont echoue(s)',
    'Vos tests ont echoue.',
    'Votre code source est mauvais et vous devrez vous sentir mal',
    'Vous avez un code source de Destruction Massive',
    'Jeu plutot etrange game. Le seul moyen de gagner est de ne pas l\'essayer',
    'Meme ma grand-mere ecrivait de meilleurs tests sur un PIII x86',
    'A chaque erreur, prenez une biere',
    'Ca craint, mon pote'
  },
  success_messages = {
    'Oh yeah, tests reussis',
    'Pas grave, y\'a eu du succes',
    'C\'est du bon, mon pote. Que du bon!',
    'Reussi, haut la main!',
    'Test reussi. Un de plus. Offre toi une biere, sur mon compte!',
  }
}
