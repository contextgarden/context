if not modules then modules = { } end modules ['strc-usr'] = {
    version   = 1.000,
    comment   = "companion to strc-usr.mkiv",
    author    = "Wolfgang Schuster",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The following is copied from \type {tabl-xtb.lua} to make the userdata environment
-- work with \LUA\ documents.

local context         = context
local ctxcore         = context.core

local startuserdata   = ctxcore.startuserdata
local stopuserdata    = ctxcore.stopuserdata

local startcollecting = context.startcollecting
local stopcollecting  = context.stopcollecting

function ctxcore.startuserdata(...)
    startcollecting()
    startuserdata(...)
end

function ctxcore.stopuserdata()
    stopuserdata()
    stopcollecting()
end
