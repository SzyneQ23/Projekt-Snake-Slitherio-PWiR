#ifndef NETWORK_PACKETS_H_
#define NETWORK_PACKETS_H_

#include "constants.h"

typedef enum {
    PACKET_BOARD_DATA
} PacketType;

typedef struct {
    int pos_x;
    int pos_y;
} BoardPlayerData;

typedef struct {
    int player_count;
    BoardPlayerData players[MAX_PLAYER_COUNT];
} BoardData;

typedef struct {
    int size;
    PacketType packet_type;
    union {
        BoardData board_data;
    };
} NetworkPacket;


#endif // NETWORK_PACKETS_H_
