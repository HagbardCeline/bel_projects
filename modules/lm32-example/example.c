/********************************************************************************************
 *  example.c
 *
 *  created : 2017
 *  author  : Dietrich Beck, Mathias Kreider GSI-Darmstadt
 *  version : 15-Mar-2017
 *
 *  example program for lm32 softcore on GSI timing receivers
 * 
 *  a few things are demonstrated
 *  - exchange of data via shared RAM. Shared RAM is accessible from the lm32 (this program) 
 *    and via Wishbone from outside the LM32.
 *  - communication with other Wishbone devices
 *
 * -------------------------------------------------------------------------------------------
 * License Agreement for this software:
 *
 * Copyright (C) 2017  Dietrich Beck
 * GSI Helmholtzzentrum für Schwerionenforschung GmbH
 * Planckstraße 1
 * D-64291 Darmstadt
 * Germany
 *
 * Contact: d.beck@gsi.de
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *
 * For all questions and ideas contact: d.beck@gsi.de
 * Last update: 25-April-2015
 ********************************************************************************************/

/* standard includes */
#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include <stdint.h>
#include "mprintf.h"
#include "mini_sdb.h"

/* includes specific for bel_projects */
#include "irq.h"
#include "aux.h"
#include "dbg.h"
#include "../../ip_cores/wr-cores/modules/wr_eca/eca_queue_regs.h"
#include "../../top/gsi_scu/scu_mil.h"


/* register maps for some selected Wishbone devices  */
#include "../../tools/wb_slaves.h" /* this is a hack */

/* shared memory map for communication via Wishbone  */
#include "example_shared_mmap.h"
#include "example_smmap.h"

/* stuff required for environment */
extern uint32_t*       _startshared[];
unsigned int cpuId, cpuQty;
#define SHARED __attribute__((section(".shared")))
uint64_t SHARED dummy = 0;

uint32_t *pECAQ;                 /* WB address of ECA queue                                                    */
unsigned int  *pMILDevicebus;    /* WB address of MIL device bus (MIL piggy)                                   */
uint32_t *pShared;               /* pointer to begin of shared memory region                                   */
uint32_t *pSharedCounter;        /* pointer to a "user defined" u32 register; here: publish counter            */
volatile uint32_t *pSharedInput; /* pointer to a "user defined" u32 register; here: get input from host system */
volatile uint32_t *pSharedCmd;   /* pointer to a "user defined" u32 register; here: get commnand from host s.  */
uint32_t *pCpuRamExternal;       /* external address (seen from host bridge) of this CPU's RAM                 */

/*
void show_msi()
{
  mprintf(" Msg:\t%08x\nAdr:\t%08x\nSel:\t%01x\n", global_msi.msg, global_msi.adr, global_msi.sel);
}

void isr0()
{
  mprintf("ISR0\n");   
  show_msi();
}
*/

void init()
{
  /* mini-sdb: get info on important Wishbone infrastructure, such as (this) CPU, flash, EB Master, ... */
  discoverPeriphery();
  /* init UART, required for printf... . To view print message, you may use 'eb-console' from the host  */
  uart_init_hw();
  /* get ID of THIS CPU */ 
  cpuId = getCpuIdx();
  /* ebmInit(); 
  /* set MSI IRQ handler */
  isr_table_clr();
  irq_set_mask(0x01);
  irq_disable(); 
} /* init */

/***********************************************************
 *  
 * demonstrate how to talk to a SoC Wishbone device
 * here: get White Rabbit time from WR PPS GEN
 *
 ***********************************************************/
void getWishboneTAI()
{
  uint32_t *pPPSGen;            /* WB address of PPS_GEN     */
  uint32_t taiSecs;             /* TAI full seconds          */
  uint32_t taiNsecs;            /* TAI nanoseconds part      */

  /* get Wishbone address of WR PPS GEN                      */
  pPPSGen   = find_device_adr(WR_PPS_GEN_VENDOR, WR_PPS_GEN_PRODUCT);

  /* get data from WR PPS GEN and print to UART              */
  taiSecs  = *(pPPSGen + (WR_PPS_GEN_CNTR_UTCLO >> 2));
  taiNsecs = *(pPPSGen + (WR_PPS_GEN_CNTR_NSEC >> 2));

  /* print TAI to UART */
  mprintf("TAI: %08u.%09u\n", taiSecs, taiNsecs);

} /* getWishboneTAI */

/***********************************************************
 *
 * demonstrate exchange of data to Wishbone via shared RAM 
 * - the data can be accessed via Etherbone->Wishbone
 * - try eb-read/eb-write from the host system
 *
 ***********************************************************/
void useSharedMem()
{
  int      i,j;
  uint32_t idx;
  const uint32_t c_Max_Rams = 10;
  sdb_location found_sdb[c_Max_Rams];
  sdb_location found_clu;

  /* get pointer to shared memory       */                    
  pShared        = (uint32_t *)_startshared;
  pSharedCounter = (uint32_t *)(pShared + (EXAMPLE_SHARED_COUNTER >> 2));
  pSharedInput   = (uint32_t *)(pShared + (EXAMPLE_SHARED_INPUT >> 2));

  /* print local pointer info to UART   */
  mprintf("internal shared memory: start            @ 0x%08x\n", (uint32_t)pShared);
  mprintf("internal shared memory: counter address  @ 0x%08x\n", (uint32_t)pSharedCounter);
  mprintf("internal shared memory: input address    @ 0x%08x\n", (uint32_t)pSharedInput);

  idx = 0;
  find_device_multi(&found_clu, &idx, 1, GSI, LM32_CB_CLUSTER);	
  idx = 0;
  find_device_multi_in_subtree(&found_clu, &found_sdb[0], &idx, c_Max_Rams, GSI, LM32_RAM_USER);
  if(idx >= cpuId) {
    pCpuRamExternal = (uint32_t*)(getSdbAdr(&found_sdb[cpuId]) & 0x7FFFFFFF); /* CPU sees the 'world' under 0x8..., remove that bit to get host bridge perspective */
    /* print external WB info to UART     */
    mprintf("external WB address   : counter offset   @ 0x%08x\n", (uint32_t)(pCpuRamExternal + ((EXAMPLE_SHARED_COUNTER + SHARED_OFFS) >> 2)));
    mprintf("external WB address   : input offset     @ 0x%08x\n", (uint32_t)(pCpuRamExternal + ((EXAMPLE_SHARED_INPUT   + SHARED_OFFS) >> 2))); 
  } else {
    pCpuRamExternal = (uint32_t*)ERROR_NOT_FOUND;
    mprintf("Could not find external WB address of my own RAM !\n");
  }
  
  
  /* initialize values of shared memory */
  *pSharedCounter = 0x0;
  *pSharedInput   = 0x0;

  /* write counter value to shared memory. Moreover, read and print value from shared memory               */
  /* initialize counter */
  i=0;
  while (i<10) {
    for (j = 0; j < (3100000*5); ++j) { asm("nop"); }   /* wait for 500ms                                  */
    i++;
    /* write value of counter 'i' to shared memory. Use eb-read to obtain the value from the host system.  */
    *pSharedCounter = i;
    /* read and print value from shared memory                                                             */
    /* via Wishbone - from outside the lm32, change the value of the input register (eb-write form host).  */
    /* Use 'eb-console' to see printed value                                                               */
    mprintf("value of input register: 0d%08d\n", *pSharedInput);
  } /* while 1 */

} /* useSharedMem */


/*************************************************************
* 
* demonstrate how to talk to MIL devicebus
* HERE: get WB address of Wishbone device GSI_MIL_SCU
*
**************************************************************/
void initMILDevicebus(){
  /* get Wishbone address for MIL Devicebus         */
  pMILDevicebus   = (unsigned int*)find_device_adr(GSI, SCU_MIL);
  mprintf("pMILDevicebus: 0x%08x\n",  pMILDevicebus);
} /* init MILDevicebus */


/*************************************************************
* 
* demonstrate how to talk to a MIL device
* HERE: write (read) data to (from)  the echo register of 
* a MIL device
*
**************************************************************/
void testEchoMILDevice(short wData)
{
  short ifkAddr  = 0x20;   /* address of interface card               */
  short fcEchoW  = 0x13;   /* function code: write to echo register   */
  short fcEchoR  = 0x89;   /* function code: read from echo register  */
  short rData    = 0x0;    /* data to read                            */
  unsigned short fc_ifk;   /* function code and interface card addr   */
  int busStatus = 0;       /* status of bus operation                 */
  int j;

  mprintf("writeData: 0x%x to IFK with address 0x%x\n", wData, ifkAddr);

  /* write to echo register */
  fc_ifk = ifkAddr | (fcEchoW << 8);
  busStatus = write_mil(pMILDevicebus, wData, fc_ifk);
  mprintf("fc_ifk: 0x%x - bus status: %d\n", fc_ifk, busStatus);

  /* read from echo register */
  fc_ifk = ifkAddr | (fcEchoR << 8);
  busStatus = read_mil(pMILDevicebus, &rData, fc_ifk);
  mprintf("fc_ifk: 0x%x - bus status: %d\n", fc_ifk, busStatus);
  
  mprintf("readData: 0x%x from IFK with address 0x%x\n", rData, ifkAddr);

} /* testEchoMILDevice */


/*************************************************************
* 
* demonstrate how to poll actions ("events") from ECA
* HERE: get WB address of relevant ECA queue
*
**************************************************************/
void initEca()
{
#define ECAQMAX           4
#define ECACHANNELFORLM32 2     /* this is a hack!           */
  /* stuff below needed to get WB address of ECA queue       */
  sdb_location ECAQ_base[ECAQMAX];
  uint32_t ECAQidx = 0;         
  uint32_t *tmp;                
  int i;

  /* get Wishbone address of ECA queue                       */
  /* get list of ECA queues                                  */
  find_device_multi(ECAQ_base, &ECAQidx, ECAQMAX, ECA_QUEUE_SDB_VENDOR_ID, ECA_QUEUE_SDB_DEVICE_ID);
  pECAQ = 0x0;
  /* find ECA queue connected to ECA chanel for LM32         */
  for (i=0; i < ECAQidx; i++) {
    tmp = (uint32_t *)(getSdbAdr(&ECAQ_base[i]));  
    if ( *(tmp + (ECA_QUEUE_QUEUE_ID_GET >> 2)) == ECACHANNELFORLM32) pECAQ = tmp;
  }
  mprintf("\n");
  if (!pECAQ) { mprintf("FATAL: can't find ECA queue for lm32, good bye! \n"); while(1) asm("nop"); }
  mprintf("ECA queue found at: %08x. Waiting for actions ...\n", pECAQ);
  mprintf("\n");

} /* initeca */

/*************************************************************
* 
* demonstrate how to poll actions ("events") from ECA
* HERE: poll ECA, get data of action and do something
*
* This example assumes that
* - action for this lm32 are configured by using saft-ecpu-ctl
*   from the host system
* - a TAG with value 0x4 has been configure (see saft-ecpu-ctl -h
*   for help
*
**************************************************************/
void ecaHandler()
{
  uint32_t flag;                /* flag for the next action  */
  uint32_t evtIdHigh;           /* high 32bit of eventID     */
  uint32_t evtIdLow;            /* low 32bit of eventID      */
  uint32_t evtDeadlHigh;        /* high 32bit of deadline    */
  uint32_t evtDeadlLow;         /* low 32bit of deadline     */
  uint32_t actTag;              /* tag of action             */

  /* read flag and check if there was an action              */
  flag         = *(pECAQ + (ECA_QUEUE_FLAGS_GET >> 2));
  if (flag & 0x10) { /* data is valid?                       */
    
    /* read data */
    evtIdHigh    = *(pECAQ + (ECA_QUEUE_EVENT_ID_HI_GET >> 2));
    evtIdLow     = *(pECAQ + (ECA_QUEUE_EVENT_ID_LO_GET >> 2));
    evtDeadlHigh = *(pECAQ + (ECA_QUEUE_DEADLINE_HI_GET >> 2));
    evtDeadlLow  = *(pECAQ + (ECA_QUEUE_DEADLINE_LO_GET >> 2));
    actTag       = *(pECAQ + (ECA_QUEUE_TAG_GET >> 2));
    
    /* pop action from channel */
    *(pECAQ + (ECA_QUEUE_POP_OWR >> 2)) = 0x1;

    /* here: do s.th. according to action                    */
    switch (actTag) {
    case 0x4:
      mprintf("EvtID: 0x%08x%08x; deadline: %08x%08x; flag: %08x\n", evtIdHigh, evtIdLow, evtDeadlHigh, evtDeadlLow, flag);
      break;
    default:
      mprintf("ecaHandler: unknown tag\n");
    } /* switch */

  } /* if data is valid */
} /* ecaHandler */

/*************************************************************
* 
* demonstrate how to poll actions ("events") from ECA
* HERE: get WB address of relevant ECA queue
*
**************************************************************/
void initCmds()
{
  /* get pointer to shared memory */ 
  pSharedCmd     = (uint32_t *)(pShared + (EXAMPLE_SHARED_CMD >> 2));

  /* print pointer info to UART */
  mprintf("\n");
  mprintf("internal shared memory: command address  @ 0x%08x\n", (uint32_t)pSharedCmd);
  mprintf("external WB address   : command offset   @ 0x%08x\n", (uint32_t)(pCpuRamExternal + ((EXAMPLE_SHARED_CMD + SHARED_OFFS) >> 2)));
  mprintf("\n");

  /* initalize command value: 0x0 means 'no command        */
  *pSharedCmd     = 0x0;

  mprintf("Waiting for commands...\n");
} /* initCmds */

/*************************************************************
* 
* demonstrate how to handle received commands
* - the data can be accessed via Etherbone->Wishbone
* - try eb-write from the host system
* after a command has been processed, the command value
* in the shared memory is reset to 0x0.
*
**************************************************************/
void cmdHandler()
{
  /* check, if a command has been issued (no cmd: 0x0)       */
  //  mprintf("value of command input : 0x%08x\n", *pSharedCmd);
  if (*pSharedCmd) {
    switch (*pSharedCmd) {
    case 0x1:
      mprintf("received cmd 0x1\n");
      break;
    case 0x2:
      mprintf("received cmd 0x2\n");
      break;
    case 0x3:
      mprintf("received cmd 0x3\n");
      break;
    default:
      mprintf("cmdHandler: unknown command '0x%08x'\n",*pSharedCmd);
    } /* switch */
    *pSharedCmd = 0x0; /* reset cmd value in shared memory   */
  } /* if command */
} /* ecaHandler */

void main(void) {
  
  int i,j;
  
  /* initialize 'boot' lm32 */
  init();
  
  /* wait 1 second and print initial message to UART         */
  for (j = 0; j < (31000000); ++j) { asm("nop"); }
  mprintf("Hello World!\n");

  getWishboneTAI();      /* get TAI via WB and print to UART */
  useSharedMem();        /* read/write to shared memory      */
  initEca();             /* init for actions from ECA        */
  initCmds();            /* init for cmds from shared mem    */
  initMILDevicebus();    /* init MIL devicebus master        */
  testEchoMILDevice(0xbabe);  /* write/read to MIL device    */

  i=0;
  while (1) {
    /* do the things that have to be done                    */
    ecaHandler();
    cmdHandler();

    /* increment and update iteration counter                */
    i++;
    *pSharedCounter = i;

    /* wait for 100  microseconds                            */
    for (j = 0; j < (25000); ++j) { asm("nop"); }
  } /* while */
} /* main */