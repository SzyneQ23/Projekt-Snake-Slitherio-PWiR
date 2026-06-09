#ifndef NETWORK_PACKETS_H_
#define NETWORK_PACKETS_H_

#include "constants.h"

typedef enum {
    PACKET_GAME_DATA,
    PACKET_PLAYER_INPUT,
} PacketType;

typedef struct {
      int x;
      int y;  
} Position;

typedef struct { 
    int x; 
    int y; 
    char isActive; 
    char item_type; 
} Food;

typedef struct {
    int x;
    int y;
    char isActive;
} BonusItem;

typedef struct {
    int move_dir_x;
    int move_dir_y;
    Position pos[MAX_SNAKE_LENGTH];
    int length;
    char isAlive;
    char player_idx;
} PlayerData;


typedef struct {
    int connected_player_id;
    int player_count;

    int board_width;
    int board_height;

    PlayerData players[MAX_PLAYER_COUNT];
    Food food[MAX_NUMBER_OF_FOOD];
    BonusItem bonuses[MAX_NUMBER_OF_BONUSES];
} GameDataPacket;


typedef enum {
    Left,
    Right,
    Up,
    Down,
} PlayerInputType;

typedef struct {
    PlayerInputType input_type;
} PlayerInputEvent;


// Main struct that is sent over the network
typedef struct {
    int size;
    PacketType packet_type;

    // Data specific to given packet type
    union {
        GameDataPacket game_data;
        PlayerInputEvent input_event;
    };
} NetworkPacket;


#endif // NETWORK_PACKETS_H_
