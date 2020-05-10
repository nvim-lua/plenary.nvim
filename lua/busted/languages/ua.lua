local s = require('say')

s:set_namespace('ua')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', 'Очікує')
s:set('output.failure', 'Зламався')
s:set('output.success', 'Пройшов')

s:set('output.pending_plural', 'очікують')
s:set('output.failure_plural', 'зламались')
s:set('output.success_plural', 'пройшли')

s:set('output.pending_zero', 'очікуючих')
s:set('output.failure_zero', 'зламаних')
s:set('output.success_zero', 'пройдених')

s:set('output.pending_single', 'очікує')
s:set('output.failure_single', 'зламався')
s:set('output.success_single', 'пройшов')

s:set('output.seconds', 'секунд')


---- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    'Ти зрадив %d тестів!',
    'Ой йо..',
    'Вороги поламали наші тести!'
  },
  success_messages = {
    'Слава Україні! Героям Слава!',
    'Тестування успішно пройдено!',
    'Всі баги знищено!'
  }
}
