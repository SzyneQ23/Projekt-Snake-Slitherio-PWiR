#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>

#include "network_packets.h"

// TODO:
// - server needs to have a specified board update rate


// global board data
BoardData board_data = {
    .player_count = 0
};


void* connection_handler(void *socket_desc) {

    /* Get the socket descriptor */
    int sock = * (int *)socket_desc;
    int read_size;
    char *message , client_message[2000];


    BoardPlayerData player_data = {
        .pos_x = 0,
        .pos_y = 0
    };

    board_data.player_count = 1;
    board_data.players[0] = player_data;

    NetworkPacket packet = {
        .packet_type = PACKET_BOARD_DATA,
        .board_data = board_data
    };

    // main loop for handling client communication
    do {
        // TODO:
        // - read incoming packets from the client
        // - respond
        // - send updated board state

        packet.board_data.players[0].pos_x += 1;

        write(sock, &packet , sizeof(packet));
        sleep(1);
    } while(read_size > 2); /* Wait for empty line */

    fprintf(stderr, "Client disconnected\n");
    close(sock);
    pthread_exit(NULL);
}

const uint16_t PORT = 5000;

// How many incoming connections to hold in queue. If the number of pending connections exceeds this, they will be refused
const int PENDING_CONNECTIONS = 10;

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
    listen(socketfd, PENDING_CONNECTIONS);

    printf("Listening for connections...\n");
    for (;;) {
        connfd = accept(socketfd, (struct sockaddr*)NULL, NULL);
        fprintf(stderr, "Connection accepted\n");
        pthread_create(&thread_id, NULL, connection_handler, (void*) &connfd);
    }
}


