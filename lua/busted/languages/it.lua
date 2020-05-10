local s = require('say')

s:set_namespace('it')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', 'In attesa')
s:set('output.failure', 'Fallimento')
s:set('output.error', 'Errore')
s:set('output.success', 'Successo')

s:set('output.pending_plural', 'in attesa')
s:set('output.failure_plural', 'fallimenti')
s:set('output.error_plural', 'errori')
s:set('output.success_plural', 'successi')

s:set('output.pending_zero', 'in attesa')
s:set('output.failure_zero', 'fallimenti')
s:set('output.error_zero', 'errori')
s:set('output.success_zero', 'successi')

s:set('output.pending_single', 'in attesa')
s:set('output.failure_single', 'fallimento')
s:set('output.error_single', 'errore')
s:set('output.success_single', 'successo')

s:set('output.seconds', 'secondi')

s:set('output.no_test_files_match', 'Nessun file di test trovat che corrisponde al pattern Lua: %s')
s:set('output.file_not_found', 'Nessun file o cartella trovato: %s')

-- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    "Hai %d specifiche non conformi",
    "Le tue specifiche non sono conformi",
    "Il tuo codice fa schifo e dovresti sentirti male per questo",
    "Il tuo codice è in pericolo",
    "Strano. Il solo modo per terminare con successo i tuoi test è fare nessun test",
    "Mia nonna ha scritto migliori specifiche su un 3 86",
    "Ogni volta che trovi un errore, bevi un'altra birra",
    "I fallimenti fanno male alla salute"
  },
  success_messages = {
    "Ma andiamo! Specifiche Ok!",
    "Non importa, avevi le specifiche",
    "Bella zio",
    "Gran successo",
    "Test passato, hai vinto una birra"
  }
}
