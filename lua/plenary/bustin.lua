-- ✱◼●●●●●●●●●●●●●●●
-- 15 successes / 1 failure / 1 error / 0 pending : 0.022516 seconds

-- Failure → spec/dotnet/foo_spec.lua @ 7
-- Extract and return the properties of a test project from a 'project block' (as found in a .NET solution file):
--  get_project_path() : Should return the path of a Csharp project
-- spec/dotnet/foo_spec.lua:13: (number) 2
-- Expected objects to be equal.
-- Passed in:
-- (string) 'TestProject\TestProject.csproj'
-- Expected:
-- (string) 'TestProject\oooTestProject.csproj'

-- Error → spec/error_spec.lua:2: syntax error near <eof>
-- spec/error_spec.lua


-- == Spec Result Table ===========================
-- Status:
-- Fail, pending, success, error
-- Testfile/dir:
--      spec/dotnet/foo_spec.lua
-- Line number:
--      @ 7
-- Description:
--      Extract and return the properties of a test project 
--      get_project_path() : Should return the path of a Csharp project
-- Message:
--      Expected objects to be equal.
--      Passed in:
--      (string) 'TestProject\TestProject.csproj'
--      Expected:
--      (string) 'TestProject\oooTestProject.csproj'
-- Stack Trace:

local M = {}

return M
