local s = require('say')

s:set_namespace('ru')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', 'Ожидает')
s:set('output.failure', 'Поломалcя')
s:set('output.success', 'Прошeл')

s:set('output.pending_plural', 'ожидают')
s:set('output.failure_plural', 'поломалиcь')
s:set('output.success_plural', 'прошли')

s:set('output.pending_zero', 'ожидающих')
s:set('output.failure_zero', 'поломанных')
s:set('output.success_zero', 'прошедших')

s:set('output.pending_single', 'ожидает')
s:set('output.failure_single', 'поломался')
s:set('output.success_single', 'прошел')

s:set('output.seconds', 'секунд')

---- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    'У тебя %d просратых тестов',
    'Твои тесты поломаны',
    'Твой код говеный - пойди напейся!'
  },
  success_messages = {
    'Поехали!',
    'Жизнь - хороша!',
    'Ффух в этот раз пронесло!',
    'Ура!'
  }
}
