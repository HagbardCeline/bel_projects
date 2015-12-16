#ifndef _ACCESS_H_
#define _ACCESS_H_

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <etherbone.h>
#include "ftmx86.h"

extern eb_device_t device;
extern eb_socket_t mySocket;
extern const char* program;

#define SWAP_4(x) ( ((x) << 24) | \
         (((x) << 8) & 0x00ff0000) | \
         (((x) >> 8) & 0x0000ff00) | \
         ((x) >> 24) )


#define MAX_DEVICES 20
#define FWID_LEN 0x400
#define BOOTL_LEN 0x100
#define PACKET_SIZE  500
#define CMD_LM32_RST 0x2

typedef struct {
   uint32_t ramAdr;
   uint32_t actOffs;
   uint32_t inaOffs;
   uint32_t sharedOffs;
   uint8_t  hasValidFW;
} t_core;

typedef struct {
   uint8_t cpuQty;
   t_core* pCores;
   uint32_t resetAdr;
   uint32_t clusterAdr;
   uint32_t sharedAdr;
   uint32_t prioQAdr;
   uint32_t ebmAdr;
} t_ftmAccess;

uint32_t ftm_shared_offs;

t_ftmAccess* openFtm(const char* netaddress, t_ftmAccess* p, uint8_t overrideFWcheck);
void closeFtm(void);
const uint8_t*  ebRamRead(uint32_t address, uint32_t len, const uint8_t* buf);
const uint8_t*  ebRamWrite(const uint8_t* buf, uint32_t address, uint32_t len, uint32_t bufEndian);
void ebRamClear(uint32_t address, uint32_t len);
uint8_t isFwValid(struct sdb_device* ram, const char* sVerExp, const char* sName);
int die(eb_status_t status, const char* what);


#endif
