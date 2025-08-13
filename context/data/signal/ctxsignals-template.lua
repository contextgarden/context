-- This is a minimal setup that controls how the context runner behaves, for
-- instance in resetting states because it's the runner that actually know what is
-- happening. We can at some poitn delegate some to the run itself but as a run can
-- be aborted for various reasons it can be that it can't trigger the error state on
-- the device.

return {

    -- This is a minimalistic setup, no hue host and lamps are defined
    -- here but the manual explains it.

    comment = "an example signal (context watch) setup file",
    version = 1.001,

    -- This controls the mtxrun cq. contect scripts as well as the run
    -- itself because both need to knwo what to communicate with.

    servers = {
        squid   = {
            protocol = "serial",
            -- optional:
            baud    = 115200,
            -- Windows (check the device list for the number):
            port     = "COM6",
            -- Linux (also add user with permissions, see manual):
            port     = "/dev/ttyACM0",
            -- OSX (ls -la /dev/tty.usbserial*):
            port     = "/dev/tty.usbmodem14101",
        },
    },

    -- This controls the mtxrun cq. contect scripts as they know best
    -- what is dealt with and what happened.

    signals = {
        runner   = { enabled = true },
        squid    = { enabled = true },
        quadrant = { enabled = true },
        segment  = { enabled = true },
    },

    -- We want to use this feature so we enable it.

    usage = {
         enabled = true,
         server  = "squid",
    },

}
