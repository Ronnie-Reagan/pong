return {

    -- basic settings:
    name = 'Online Pong', -- name of the game for your executable
    developer = 'Don Reagan', -- dev name used in metadata of the file
    output = '', -- output location for your game, defaults to $SAVE_DIRECTORY
    version = '0.2', -- 'version' of your game, used to name the folder in output
    love = '11.5', -- version of LÖVE to use, must match github releases
    ignore = {'build.lua', '0.1', '0.2', 'dist', 'ignoreme.txt', 'server.log', 'client.log', '.gitignore'}, -- folders/files to ignore in your project
    icon = 'logo.png', -- 256x256px PNG icon for game, will be converted for you

    -- optional settings:
    libs = { -- files to place in output directly rather than fuse
      all = {'resources/license.txt'}
    },
    hooks = { -- hooks to run commands via os.execute before or after building
      before_build = 'resources/preprocess.sh',
      after_build = 'resources/postprocess.sh'
    }

  }