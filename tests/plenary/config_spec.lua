local Schema = require'plenary.config'.Schema

describe('Schema', function()
  it('should find descriptions', function()
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
      sub_schema = Schema {
        favorite_food = {
          type = 'string',
          default = 'none',
          description = 'favorite food',
        },
        favorite_instrument = {
          type = 'string',
          default = 'oboe',
          description = [[favorite intrument]]
        }
      }
    }

    dump(schema:descriptions())
  end)
end)
