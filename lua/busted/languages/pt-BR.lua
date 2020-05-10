local s = require('say')

s:set_namespace('pt-BR')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', 'Pendente')
s:set('output.failure', 'Falha')
s:set('output.error', 'Erro')
s:set('output.success', 'Sucesso')

s:set('output.pending_plural', 'pendentes')
s:set('output.failure_plural', 'falhas')
s:set('output.error_plural', 'erros')
s:set('output.success_plural', 'sucessos')

s:set('output.pending_zero', 'pendentes')
s:set('output.failure_zero', 'falhas')
s:set('output.error_zero', 'erros')
s:set('output.success_zero', 'sucessos')

s:set('output.pending_single', 'pendente')
s:set('output.failure_single', 'falha')
s:set('output.error_single', 'erro')
s:set('output.success_single', 'sucesso')

s:set('output.seconds', 'segundos')

s:set('output.no_test_files_match', 'Nenhum arquivo de teste encontrado com o padrão do Lua: %s')

-- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    'Você tem %d testes quebrados',
    'Seus testes estão quebrados',
    'Seu código está mal e você deveria sentir-se mal',
    'Seu código está na zona de perigo',
    'Jogo estranho. A única forma de ganhar é não testar',
    'Minha avó escreveu testes melhores em um 386',
    'Cada vez que encontrar uma falha, beba outra cerveja',
    'Isso não está poético'
  },
  success_messages = {
    'Perfeito! Todos os testes estão passando',
    'Não se preocupe, tem testes',
    'Isso está poético',
    'Excelente',
    'Os testes passaram, beba outra cerveja',
  }
}
