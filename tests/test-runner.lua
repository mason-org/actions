local TARGET, PACKAGES, GITHUB_ACTION_PATH = vim.env.TARGET, vim.env.PACKAGES, vim.env.GITHUB_ACTION_PATH

assert(TARGET, "$TARGET not set.")
assert(PACKAGES, "$PACKAGES not set.")
assert(GITHUB_ACTION_PATH, "$GITHUB_ACTION_PATH not set.")

vim.opt.rtp:prepend(GITHUB_ACTION_PATH .. "/mason.nvim")

local Pkg = require "mason-core.package"
local spawn = require "mason-core.spawn"
local _ = require "mason-core.functional"
local fs = require "mason-core.fs"
local path = require "mason-core.path"
local a = require "mason-core.async"
local registry_installer = require "mason-core.installer.registry"
local Result = require "mason-core.result"
local platform = require "mason-core.platform"
local Purl = require "mason-core.purl"

local IS_RUNNING_NATIVE_TARGET = platform.is[TARGET]

local log = setmetatable({}, {
    __index = function(__, log_level)
        return function(...)
            local args = _.map(_.if_else(_.is "table", vim.inspect, _.identity), { ... })
            print(("[test-runner] [%s]"):format(log_level:upper()), unpack(args))
        end
    end,
})

require("mason").setup {
    log_level = vim.log.levels[(vim.env.RUNNER_DEBUG == "1" and "DEBUG") or "INFO"],
}

---@param pkg_path string
local function parse_package_spec(pkg_path)
    return Result.try(function(try)
        local raw_yaml = fs.async.read_file(path.concat { vim.loop.cwd(), pkg_path })
        local raw_spec = try(spawn.yq {
            "-o",
            "json",
            on_spawn = function(_, stdio)
                local stdin = stdio[1]
                stdin:write(raw_yaml, function()
                    stdin:shutdown()
                end)
            end,
        })
        local spec = vim.json.decode(raw_spec.stdout)
        spec.schema = "registry+v1"
        return Pkg.new(spec)
    end)
end

local is_not_empty = _.complement(_.equals "")

---@param pkg Package
local function should_skip(pkg)
    return Result.try(function(try)
        if not IS_RUNNING_NATIVE_TARGET then
            local purl = try(Purl.parse(pkg.spec.source.id))
            if not (purl.type == "github" and pkg.spec.source.asset ~= nil) then
                -- Currently we can only meaningfully emulate a different target platform for GitHub release sources.
                return ("Cannot emulate target: %q"):format(TARGET)
            end
        end

        return try(registry_installer.parse(pkg.spec, { target = TARGET }):map(_.always(nil)):or_else(function(err)
            if err == "PLATFORM_UNSUPPORTED" then
                return Result.success "Unsupported platform."
            else
                return Result.failure(err)
            end
        end))
    end)
end

local ok, err = pcall(a.run_blocking, function()
    Result.try(function(try)
        local packages = _.filter(is_not_empty, _.split(" ", PACKAGES))
        log.info("Testing packages", packages)

        for __, pkg_path in ipairs(packages) do
            local pkg = try(parse_package_spec(pkg_path))
            local skip_reason = try(should_skip(pkg))
            if skip_reason == nil then
                a.scheduler()
                a.wait(function(resolve, reject)
                    pkg:once("install:success", resolve)
                    pkg:once("install:failed", reject)
                    local handle = pkg:install { target = TARGET, debug = true }
                    if vim.env.RUNNER_DEBUG == "1" then
                        handle:on("stdout", vim.schedule_wrap(print)):on("stderr", vim.schedule_wrap(print))
                    end
                end)
            else
                a.scheduler()
                log.info(("Skipping package %q: %s."):format(pkg.name, skip_reason))
            end
        end
    end):on_failure(error)
end)

if not ok then
    log.error(tostring(err))
    vim.cmd "1cq"
else
    vim.cmd "0cq"
end

-- vim:sw=4:et
