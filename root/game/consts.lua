local consts = {}

consts.TILE_SIZE = 8

consts.COLGROUP_DEFAULT = 0x1
consts.COLGROUP_ACTOR   = 0x2
consts.COLGROUP_PLAYER  = 0x4
consts.COLGROUP_ENEMY   = 0x8
consts.COLGROUP_ALL     = 0xFFFFFFFF

consts.GRAVITY = 0.1
consts.PLAYER_SIDE_SPIT_VX = 0.50
consts.PLAYER_SIDE_SPIT_CLOSE_VX = 0.25
consts.PLAYER_SIDE_SPIT_VY = -3.0
consts.PLAYER_SIDE_SPIT_TARGET_Y_OFF = 5.0
consts.PLAYER_SPIT_G_MULT = 2.0

consts.START_ROOM = "maps/b01.tmx"
consts.REQUIRED_RED_ORBS = 4
consts.RED_ORB_COUNT = 5
consts.BLUE_ORB_COUNT = 4

return consts