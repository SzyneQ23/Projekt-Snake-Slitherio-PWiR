#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>

#include "constants.h"
#include "network_packets.h"


// size of buffer used for storing incoming messages
#define RECV_BUFFER_SIZE 1024

const uint16_t PORT = 5000;

// How many incoming connections to hold in queue. If the number of pending connections exceeds this, they will be refused
const int PENDING_CONNECTIONS = 10;

typedef struct {
    int player_count;
    PlayerData players[MAX_PLAYER_COUNT];
} GameState;

// global board data - stores all snakes that are currently alive
GameState global_state = {
    .player_count = 0
};

Food food[MAX_NUMBER_OF_FOOD];
BonusItem bonuses[MAX_NUMBER_OF_BONUSES];

int is_position_free(int target_x, int target_y) {
    for (int i = 0; i < MAX_NUMBER_OF_FOOD; i++) {
        if (food[i].isActive == 1 && food[i].x == target_x && food[i].y == target_y) return 0;
    }

    for (int i = 0; i < MAX_NUMBER_OF_BONUSES; i++) {
        if (bonuses[i].isActive == 1 && bonuses[i].x == target_x && bonuses[i].y == target_y) return 0;
    }
    // --------------------------------
    
    for (int i = 0; i < global_state.player_count; i++) {
        if (global_state.players[i].isAlive == 1) {
            for(int j = 0; j < global_state.players[i].length; j++) {
                if (global_state.players[i].pos[j].x == target_x && global_state.players[i].pos[j].y == target_y) return 0;
            }
        }
    }
    return 1;
}


void handle_incoming_packet(char* bytes, int player_idx){
    NetworkPacket* packet = (NetworkPacket*)bytes;

    if(packet->packet_type == PACKET_PLAYER_INPUT){
        // change move direction for player at player_idx
        printf("Received player input event (id: %d): ", player_idx);
        switch (packet->input_event.input_type){
            case Left:
                printf("Left\n");
                global_state.players[player_idx].move_dir_x = -1;
                global_state.players[player_idx].move_dir_y = 0;
                break;
            case Right:
                printf("Right\n");
                global_state.players[player_idx].move_dir_x = 1;
                global_state.players[player_idx].move_dir_y = 0;
                break;
            case Up:
                printf("Up\n");
                global_state.players[player_idx].move_dir_x = 0;
                global_state.players[player_idx].move_dir_y = -1;
                break;
            case Down:
                printf("Down\n");
                global_state.players[player_idx].move_dir_x = 0;
                global_state.players[player_idx].move_dir_y = 1;
                break;
        }
    }
}

void* connection_handler(void *socket_desc) {

    char recv_buffer[RECV_BUFFER_SIZE];
    /* Get the socket descriptor */
    int sock = * (int *)socket_desc;
    char *message , client_message[2000];

    // index of the player assigned to this thread.
    int player_index = global_state.player_count;

    // player starts at (5, 5) pointing right
    PlayerData player_data = {
        .move_dir_x = 1,
        .move_dir_y = 0,
        .length = START_SNAKE_LENGTH,
        .pos[0].x = 5,
        .pos[0].y = 5,
        .isAlive = 1
    };

    // player data initialization (segments)
    for (int i=1; i < START_SNAKE_LENGTH; i++) {
        player_data.pos[i].x = player_data.pos[i-1].x - 1;
        player_data.pos[i].y = player_data.pos[i-1].y;
    }

    global_state.players[global_state.player_count] = player_data;
    global_state.player_count++;


    // main loop for handling client communication
    for(;;) {
        memset(recv_buffer, 0, RECV_BUFFER_SIZE);

        // ----- Handle incoming packets -----

        long read_bytes = recv(sock, recv_buffer, RECV_BUFFER_SIZE, MSG_DONTWAIT); //MSG_DONTWAIT makes it so we don't hang here when there's no data to read (default behaviour for read())
        if(read_bytes == 0){
            // return value of 0 means client disconnected
            break;
        }else if(read_bytes == -1){ // either there's no data to read or an error occurred
            if(errno == EAGAIN || errno == EWOULDBLOCK){
                // no incoming data from client at this moment
            }else{
                printf("Socket error!\n");
                break;
            }
        }else{
            handle_incoming_packet(recv_buffer, player_index);
        }

        // ----- Update board state -----

        // move player assigned to this thread
        PlayerData* player = &global_state.players[player_index];
        int dir_x = player->move_dir_x;
        int dir_y = player->move_dir_y;

        char makeLonger = 0;
        char destroySnake = 0; 
        int current_board_size = 20 + (global_state.player_count * 4);

        //check collision with other snakes
        for (int i = 0; i < global_state.player_count; i++) {
            if (i != player_index && 
                player->pos[0].x == global_state.players[i].pos[0].x &&
                player->pos[0].y == global_state.players[i].pos[0].y) {
                
                destroySnake = 1;
            }
        }

        //check collision with food
        for (int i = 0; i < MAX_NUMBER_OF_FOOD; i++) {
            if (food[i].isActive == 1 && player->pos[0].x == food[i].x && player->pos[0].y == food[i].y) {
                
                if (food[i].item_type == 0) {
                    player->length += 3; // Normalne
                    if (player->length >= MAX_SNAKE_LENGTH) player->length = MAX_SNAKE_LENGTH - 1;
                } else {
                    destroySnake = 1; // Robaczywe
                }
                
                int rx, ry;
                do {
                    rx = rand() % current_board_size;
                    ry = rand() % current_board_size;
                } while (is_position_free(rx, ry) == 0);
                
                food[i].x = rx;
                food[i].y = ry;
                food[i].item_type = rand() % 2;
            }
        }

        for (int i = 0; i < MAX_NUMBER_OF_BONUSES; i++) {
            if (bonuses[i].isActive == 1 && player->pos[0].x == bonuses[i].x && player->pos[0].y == bonuses[i].y) {
                
                player->length += 1; // Bonus
                if (player->length >= MAX_SNAKE_LENGTH) player->length = MAX_SNAKE_LENGTH - 1;
                
                int rx, ry;
                do {
                    rx = rand() % current_board_size;
                    ry = rand() % current_board_size;
                } while (is_position_free(rx, ry) == 0);
                
                bonuses[i].x = rx;
                bonuses[i].y = ry;
            }
        }

        //update snake segments
       if (destroySnake == 1) {
            player->isAlive = 0;
        }
        if (player->isAlive == 1) {
            for (int i = player->length; i > 0; i--) { 
                player->pos[i].x = player->pos[i-1].x;
                player->pos[i].y = player->pos[i-1].y;
            }
            player->pos[0].x += dir_x;
            player->pos[0].y += dir_y;
        }

        // ----- Send updated game state -----

        GameDataPacket game_data_packet = {
            .connected_player_id = player_index,
            .player_count = global_state.player_count,

            .board_width = current_board_size,
            .board_height = current_board_size
        };
        memcpy(game_data_packet.players, global_state.players, sizeof(global_state.players));
        memcpy(game_data_packet.food, food, sizeof(food));
        memcpy(game_data_packet.bonuses, bonuses, sizeof(bonuses));

        NetworkPacket packet = {
            .size = sizeof(NetworkPacket),
            .packet_type = PACKET_GAME_DATA,
            .game_data = game_data_packet
        };
        write(sock, &packet , sizeof(packet));

        // artificial delay 500ms
        // should probably find a better way to run the simulation at fixed fps
        usleep(500 * 1000);
    }; /* Wait for empty line */

    fprintf(stderr, "Player (id: %d) disconnected\n", player_index);
    close(sock);
    pthread_exit(NULL);
}




int main(int argc, char *argv[]) {
    int socketfd = 0, connfd = 0;
    struct sockaddr_in serv_addr;

    pthread_t thread_id;

    socketfd = socket(AF_INET, SOCK_STREAM, 0);
    memset(&serv_addr, '0', sizeof(serv_addr));

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    serv_addr.sin_port = htons(PORT);

    bind(socketfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));

    // Listen for incoming connections
    if (listen(socketfd, PENDING_CONNECTIONS) == -1){
        printf("Failed to start listening for connections...\n");
        exit(1);
    }

    // initialize food
    for (int i = 0; i < MAX_NUMBER_OF_FOOD; i++) {
        food[i].x = rand() % 20;
        food[i].y = rand() % 20;
        food[i].isActive = 1;
        food[i].item_type = rand() % 2; // Losuje 0 lub 1
    }

    // initialize bonuses
    for (int i = 0; i < MAX_NUMBER_OF_BONUSES; i++) {
        bonuses[i].x = rand() % 20;
        bonuses[i].y = rand() % 20;
        bonuses[i].isActive = 1;
    }

    // test (REMOVE AFTER IMPLEMENTATION IN FRONTEND)
    for (int i = 0; i < MAX_NUMBER_OF_FOOD; i++) {
        printf("Food %d is at %d, %d and is %d (active) \n", i, food[i].x, food[i].y, food[i].isActive);
    }
    
    printf("Listening for connections...\n");
    for (;;) {
        connfd = accept(socketfd, (struct sockaddr*)NULL, NULL);
        fprintf(stderr, "Connection accepted\n");
        pthread_create(&thread_id, NULL, connection_handler, (void*) &connfd);

    }
}


