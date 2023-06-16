local TARGET, VERSION, PACKAGES, GITHUB_ACTION_PATH, SKIPPED_PACKAGES =
    vim.env.TARGET, vim.env.VERSION, vim.env.PACKAGES, vim.env.GITHUB_ACTION_PATH, vim.env.SKIPPED_PACKAGES

assert(TARGET, "$TARGET not set.")
assert(PACKAGES, "$PACKAGES not set.")

local DEBUG = vim.env.RUNNER_DEBUG == "1"

if GITHUB_ACTION_PATH then
    vim.opt.rtp:prepend(GITHUB_ACTION_PATH .. "/mason.nvim")
end

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

if SKIPPED_PACKAGES then
    local skipped_packages = _.set_of(_.split(" ", SKIPPED_PACKAGES))
    PACKAGES = _.compose(
        _.join " ",
        _.filter(function(pkg)
            return not skipped_packages[pkg]
        end),
        _.split " "
    )(PACKAGES)
end

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
    log_level = vim.log.levels[DEBUG and "DEBUG" or "INFO"],
}

local yq = vim.fn.exepath "yq"

---@param pkg_path string
local function parse_package_spec(pkg_path)
    return Result.try(function(try)
        local raw_yaml = fs.async.read_file(path.concat { vim.loop.cwd(), pkg_path })
        local raw_spec = try(spawn[yq] {
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
local function get_targets(pkg)
    if not IS_RUNNING_NATIVE_TARGET then
        local purl = Purl.parse(pkg.spec.source.id):get_or_throw()
        if purl.type ~= "generic" and not (purl.type == "github" and pkg.spec.source.asset ~= nil) then
            -- Currently we can only meaningfully emulate a different target platform for GitHub release sources.
            return Result.failure(("Cannot emulate target: %q"):format(TARGET))
        end
    end

    if pkg.spec.ci_skip then
        if pkg.spec.ci_skip == true then
            return Result.failure "ci_skip enabled for all targets"
        elseif _.any(_.equals(TARGET), pkg.spec.ci_skip) then
            return Result.failure "ci_skip enabled for current target"
        end
    end

    local targets = { TARGET }
    if vim.startswith(TARGET, "darwin") then
        table.insert(targets, "darwin")
        table.insert(targets, "unix")
    elseif vim.startswith(TARGET, "linux") then
        table.insert(targets, "linux")
        table.insert(targets, "unix")
    elseif vim.startswith(TARGET, "win") then
        table.insert(targets, "win")
    end

    if VERSION then
        for _, target in ipairs(targets) do
            if registry_installer.parse(pkg.spec, { target = target, version = VERSION }):is_success() then
                return Result.success { { target = target, version = VERSION } }
            else
                return Result.failure(("Unsupported platform (version=%s)."):format(VERSION))
            end
        end
    end

    local sources = vim.list_extend({ pkg.spec.source }, pkg.spec.source.version_overrides or {})
    local resolved_targets = {}
    for _, source in ipairs(sources) do
        for _, target in ipairs(targets) do
            if
                Purl.parse(source.id)
                    :and_then(function(purl)
                        return registry_installer
                            .parse(pkg.spec, { target = target, version = purl.version })
                            :on_success(function()
                                table.insert(resolved_targets, { target = target, version = purl.version })
                            end)
                    end)
                    :is_success()
            then
                break
            end
        end
    end

    if #resolved_targets > 0 then
        return Result.success(resolved_targets)
    else
        return Result.success "Unsupported platform."
    end
end

local ok, err = pcall(a.run_blocking, function()
    Result.try(function(try)
        local packages = _.filter(is_not_empty, _.split(" ", PACKAGES))
        log.info("Testing packages", packages)

        for __, pkg_path in ipairs(packages) do
            local pkg = try(parse_package_spec(pkg_path))
            a.scheduler()
            get_targets(pkg)
                :on_success(function(targets)
                    for _, target in ipairs(targets) do
                        a.scheduler()
                        log.info("Installing", pkg.name, target)
                        a.wait(function(resolve, reject)
                            pkg:once("install:success", resolve)
                            pkg:once("install:failed", reject)
                            local handle = pkg:install {
                                target = target.target,
                                version = target.version,
                                debug = DEBUG,
                                strict = true,
                            }
                            if DEBUG then
                                handle:on("stdout", vim.schedule_wrap(print)):on("stderr", vim.schedule_wrap(print))
                            end
                        end)
                    end
                end)
                :on_failure(function(err)
                    a.scheduler()
                    log.info(("Skipping package %q: %s."):format(pkg.name, err))
                end)
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
