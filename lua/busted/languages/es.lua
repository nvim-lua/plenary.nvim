local s = require('say')

s:set_namespace('es')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', 'Pendiente')
s:set('output.failure', 'Fallo')
s:set('output.error', 'Error')
s:set('output.success', 'Éxito')

s:set('output.pending_plural', 'pendientes')
s:set('output.failure_plural', 'fallos')
s:set('output.error_plural', 'errores')
s:set('output.success_plural', 'éxitos')

s:set('output.pending_zero', 'pendientes')
s:set('output.failure_zero', 'fallos')
s:set('output.error_zero', 'errores')
s:set('output.success_zero', 'éxitos')

s:set('output.pending_single', 'pendiente')
s:set('output.failure_single', 'fallo')
s:set('output.error_single', 'error')
s:set('output.success_single', 'éxito')

s:set('output.seconds', 'segundos')

s:set('output.no_test_files_match', 'Ningún fichero de prueba fue encontrado para el patrón de Lua: %s')

-- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    'Tienes %d especificaciones o pruebas con errores',
    'Tus especificaciones o pruebas están dañadas',
    'Tu código es malo y deberías sentirte mal',
    'Tu código está en la Zona de Peligro',
    'Juego extraño. La única forma de ganar es omitiendo las pruebas',
    'Mi abuela escribió mejores especificaciones en una 386',
    'Cada vez que encuentres un fallo, tómate otra cerveza',
    'Esto no está del todo bien amigo'
  },
  success_messages = {
    'Ohhh si! Pasando todas las pruebas',
    'No importa, tenía especificaciones',
    'Esto está bien amigo',
    'Un exitazo',
    'Pasaron las pruebas, tómate otra cerveza',
  }
}
