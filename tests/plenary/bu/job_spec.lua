--[[
--
-- TODO: We should actually write the tests here, these are just examples.
local Job = require('plenary.job')

describe('Job', function()
  it('should_chain_data', function()
    local first_job = Job:new(...)
    local second_job = Job:new(...)

    -- Different options
    first_job:chain(second_job)
    first_job:and_then(second_job)
    first_job:then(second_job)

    Job.chain(first_job, second_job)

    first_job:after(function() ... end)

    -- Different kinds of things
    -- 1. Run one job, then run another (only when finished, possibly w/ the results)
    -- 2. Run one job, when done, run some synchronous code (just some callback, not necessarily a Job)
    -- 3. Pipe stdout of one job, to the next job

    -- Example 1:
    -- I have a job that searches the file system for X
    -- I have another job that determines the git status for X

    -- Example 2:
    -- I have a job that does some file system stuff
    -- I want to prompt the user what to do when it's done
  end)

end)
--]]
