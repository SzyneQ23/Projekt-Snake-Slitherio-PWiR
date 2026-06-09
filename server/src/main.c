#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include <errno.h>
#include <time.h>

#include "constants.h"
#include "network_packets.h"


// size of buffer used for storing incoming messages
#define RECV_BUFFER_SIZE 1024

const uint16_t PORT = 5000;

// How many incoming connections to hold in queue. If the number of pending connections exceeds this, they will be refused
const int PENDING_CONNECTIONS = 10;

typedef struct {
    int player_count;
    int player_sockets[MAX_PLAYER_COUNT]; // Stores client sockets for broadcasting game state
    PlayerData players[MAX_PLAYER_COUNT];
} GameState;

// global board data - stores all snakes that are currently alive
GameState global_state = {
    .player_count = 0
};

Food food[MAX_NUMBER_OF_FOOD];
BonusItem bonuses[MAX_NUMBER_OF_BONUSES];

// Mutex for synchronizing access to shared game structures between threads
pthread_mutex_t game_mutex = PTHREAD_MUTEX_INITIALIZER;

// Arguments structure to safely pass data to connection handler threads
typedef struct {
    int socket;
    int player_idx;
} ThreadArgs;

int is_position_free(int target_x, int target_y) {
    for (int i = 0; i < MAX_NUMBER_OF_FOOD; i++) {
        if (food[i].isActive == 1 && food[i].x == target_x && food[i].y == target_y) return 0;
    }

    for (int i = 0; i < MAX_NUMBER_OF_BONUSES; i++) {
        if (bonuses[i].isActive == 1 && bonuses[i].x == target_x && bonuses[i].y == target_y) return 0;
    }
    // --------------------------------
    
    for (int i = 0; i < MAX_PLAYER_COUNT; i++) {
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
        
        pthread_mutex_lock(&game_mutex); // Protect state modification
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
        pthread_mutex_unlock(&game_mutex);
    }
}

void* connection_handler(void *args) {
    ThreadArgs* t_args = (ThreadArgs*)args;
    int sock = t_args->socket;
    int player_index = t_args->player_idx;
    free(t_args); // Free dynamically allocated thread arguments

    char recv_buffer[RECV_BUFFER_SIZE];

    // main loop for handling client communication
    for(;;) {
        memset(recv_buffer, 0, RECV_BUFFER_SIZE);

        // ----- Handle incoming packets -----

        // Block until a new packet arrives from the client (instant reactivity)
        long read_bytes = recv(sock, recv_buffer, RECV_BUFFER_SIZE, 0); 
        if(read_bytes <= 0){
            // return value of 0 or -1 means client disconnected or an error occurred
            break;
        }else{
            handle_incoming_packet(recv_buffer, player_index);
        }
    }

    fprintf(stderr, "Player (id: %d) disconnected\n", player_index);
    
    pthread_mutex_lock(&game_mutex);
    global_state.players[player_index].isAlive = 0;
    global_state.player_sockets[player_index] = -1;
    pthread_mutex_unlock(&game_mutex);

    close(sock);
    pthread_exit(NULL);
}

// Independent Game Loop Thread running at a fixed tick rate
void* game_loop_thread(void* arg) {
    const int TICK_RATE_MS = 150; // Simulation step interval

    for(;;) {
        usleep(TICK_RATE_MS * 1000);

        pthread_mutex_lock(&game_mutex);

        int current_board_size = 20 + (global_state.player_count * 4);

        // ----- Update board state -----

        // move all alive players
        for (int p = 0; p < MAX_PLAYER_COUNT; p++) {
            PlayerData* player = &global_state.players[p];
            if (!player->isAlive) continue;

            int dir_x = player->move_dir_x;
            int dir_y = player->move_dir_y;

            for (int i = player->length; i > 0; i--) { 
                player->pos[i].x = player->pos[i-1].x;
                player->pos[i].y = player->pos[i-1].y;
            }
            player->pos[0].x += dir_x;
            player->pos[0].y += dir_y;
        }

        // check collisions, eat food and bonuses for all players
        for (int p = 0; p < MAX_PLAYER_COUNT; p++) {
            PlayerData* player = &global_state.players[p];
            if (!player->isAlive) continue;

            char destroySnake = 0;

            // Optional: check collision with walls
            if (player->pos[0].x < 0 || player->pos[0].x >= current_board_size || 
                player->pos[0].y < 0 || player->pos[0].y >= current_board_size) {
                destroySnake = 1;
                printf("Player %d hit a wall\n", p);
            }

            // check collision with other snakes
            for (int i = 0; i < MAX_PLAYER_COUNT; i++) {
                if(destroySnake == 1) break;// early return
                if (global_state.players[i].isAlive) {
                    int start_seg = (i == p) ? 1 : 0;
                    for(int j = start_seg; j < global_state.players[i].length; j++) {
                        if (player->pos[0].x == global_state.players[i].pos[j].x &&
                            player->pos[0].y == global_state.players[i].pos[j].y) {
                            destroySnake = 1;
                        }
                    }
                }
                if(destroySnake == 1){
                    printf("Player %d hit another snake (%d)\n", p, i);
                    break;
                }
            }

            // check collision with food
            for (int i = 0; i < MAX_NUMBER_OF_FOOD; i++) {
                if (food[i].isActive == 1 && player->pos[0].x == food[i].x && player->pos[0].y == food[i].y) {
                    
                    if (food[i].item_type == 0) {
                        int old_length = player->length;
                        player->length += 3; 
                        if (player->length >= MAX_SNAKE_LENGTH) player->length = MAX_SNAKE_LENGTH - 1;
            
                        for(int k = old_length; k < player->length; k++) {
                            player->pos[k] = player->pos[old_length - 1]; 
                        }
                    } else {
                        destroySnake = 1; 
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

            // check collision with bonuses
            for (int i = 0; i < MAX_NUMBER_OF_BONUSES; i++) {
                if (bonuses[i].isActive == 1 && player->pos[0].x == bonuses[i].x && player->pos[0].y == bonuses[i].y) {
                    
                    int old_length = player->length;
                    player->length += 1; 
                    if (player->length >= MAX_SNAKE_LENGTH) player->length = MAX_SNAKE_LENGTH - 1;
                    
                    player->pos[old_length] = player->pos[old_length - 1];
                    
                    int rx, ry;
                    do {
                        rx = rand() % current_board_size;
                        ry = rand() % current_board_size;
                    } while (is_position_free(rx, ry) == 0);
                    
                    bonuses[i].x = rx;
                    bonuses[i].y = ry;
                }
            }

            // update snake segments
            if (destroySnake == 1) {
                player->isAlive = 0;
            }
        }

        // ----- Send updated game state to ALL connected clients -----
        for (int p = 0; p < MAX_PLAYER_COUNT; p++) {
            int sock = global_state.player_sockets[p];
            if (sock == -1) continue;

            GameDataPacket game_data_packet = {
                .connected_player_id = p,
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
            
            write(sock, &packet, sizeof(packet));
        }

        pthread_mutex_unlock(&game_mutex);
    }
    return NULL;
}


int main(int argc, char *argv[]) {
    srand(time(NULL));
    int socketfd = 0, connfd = 0;
    struct sockaddr_in serv_addr;

    pthread_t thread_id;

    // Explicitly initialize empty slot states to avoid 0-initialization bugs
    for(int i = 0; i < MAX_PLAYER_COUNT; i++) {
        global_state.player_sockets[i] = -1;
        global_state.players[i].isAlive = 0;
    }

    socketfd = socket(AF_INET, SOCK_STREAM, 0);
    
    // Allow immediate port reuse after server restart
    int opt = 1;
    setsockopt(socketfd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

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
        food[i].item_type = rand() % 2; 
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
    
    // START THE MAIN GAME LOOP THREAD
    pthread_t game_loop_id;
    pthread_create(&game_loop_id, NULL, game_loop_thread, NULL);
    
    printf("Listening for connections...\n");
    for (;;) {
        connfd = accept(socketfd, (struct sockaddr*)NULL, NULL);
        fprintf(stderr, "Connection accepted\n");

        pthread_mutex_lock(&game_mutex);

        // find first free slot
        int player_index = -1;
        for(int i=0; i< MAX_PLAYER_COUNT; i++){
            if(global_state.player_sockets[i] == -1){
                player_index = i;
                break;
            }
        }

        if(player_index == -1){
            printf("Server full, connection rejected.\n");
            close(connfd);
            pthread_mutex_unlock(&game_mutex);
            continue;
        }
        printf("found index: %d\n", player_index);

        global_state.player_sockets[player_index] = connfd;

        // Completely clear old data buffer for this exact slot before rewriting
        memset(&global_state.players[player_index], 0, sizeof(PlayerData));

        // find a clean, non-colliding starting coordinate for the new connection
        int current_board_size = 20 + (global_state.player_count * 4);
        int rand_start_x, rand_start_y;
        do {
            rand_start_x = (rand() % (current_board_size - START_SNAKE_LENGTH)) + START_SNAKE_LENGTH;
            rand_start_y = rand() % current_board_size;
        } while (is_position_free(rand_start_x, rand_start_y) == 0);

        PlayerData player_data = {
            .move_dir_x = 1,
            .move_dir_y = 0,
            .length = START_SNAKE_LENGTH,
            .pos[0].x = rand_start_x,
            .pos[0].y = rand_start_y,
            .isAlive = 1,
            .player_idx = player_index
        };

        // player data initialization (segments)
        for (int i=1; i < START_SNAKE_LENGTH; i++) {
            player_data.pos[i].x = player_data.pos[i-1].x - 1;
            player_data.pos[i].y = player_data.pos[i-1].y;
        }

        global_state.players[player_index] = player_data;
        
        if (player_index >= global_state.player_count) {
            global_state.player_count = player_index + 1;
        }
        
        pthread_mutex_unlock(&game_mutex);

        // Safe argument passing using dynamic allocation
        ThreadArgs* args = malloc(sizeof(ThreadArgs));
        args->socket = connfd;
        args->player_idx = player_index;

        pthread_create(&thread_id, NULL, connection_handler, (void*)args);
        pthread_detach(thread_id); // Automatically detach thread to reclaim resources upon exit
    }
}