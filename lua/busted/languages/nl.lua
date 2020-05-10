local s = require('say')

s:set_namespace('nl')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', 'Hangend')
s:set('output.failure', 'Mislukt')
s:set('output.success', 'Succes')

s:set('output.pending_plural', 'hangenden')
s:set('output.failure_plural', 'mislukkingen')
s:set('output.success_plural', 'successen')

s:set('output.pending_zero', 'hangend')
s:set('output.failure_zero', 'mislukt')
s:set('output.success_zero', 'successen')

s:set('output.pending_single', 'hangt')
s:set('output.failure_single', 'mislukt')
s:set('output.success_single', 'succes')

s:set('output.seconds', 'seconden')

-- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    'Je hebt %d busted specs',
    'Je specs zijn busted',
    'Je code is slecht en zo zou jij je ook moeten voelen',
    'Je code zit in de Gevaren Zone',
    'Vreemd spelletje. The enige manier om te winnen is door niet te testen',
    'Mijn oma schreef betere specs op een 3 86',
    'Elke keer dat iets mislukt, nog een biertje drinken',
    'Voelt klote man'
  },
  success_messages = {
    'Joeperdepoep, de specs zijn er door',
    'Doet er niet toe, had specs',
    'Voelt goed, man',
    'Fantastisch success',
    'Testen geslaagd, neem nog een biertje',
  }
}
