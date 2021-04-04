local Schema = require'plenary.config'.Schema

local schema = Schema {
  person = {
    type = 'string',
    default = 'oberblastmeister',
    description = [[My name]],
  },
  languages = {
    type = 'table',
    deep_extend = true,
    default = {
      'rust',
      'haskell',
      'lua',
      'python',
    },
    description = [[The languages I like]]
  },
  favorite = Schema {
    food = {
      type = 'string',
      default = 'none',
      description = 'favorite food',
    },
    instrument = {
      type = 'string',
      default = 'oboe',
      description = [[favorite intrument]]
    }
  },
  sub1 = Schema {
    sub2 = Schema {
      hello = {
        type = 'boolean',
        default = true,
        description = 'whether to say hello'
      }
    },
    an_option_in_sub1 = {
      type = 'boolean',
      default = true,
      description = 'just a test'
    }
  }
}

dump(schema:descriptions():tolist())
