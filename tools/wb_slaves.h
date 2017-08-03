/* *******************************************************************************************
 * wb_slaves.h
 *
 *
 *  created : 11-Nov-2016
 *  author  : Dietrich Beck, GSI-Darmstadt
 *  version : 02-Aug-2017
 */
#define WB_SLAVES_VERSION "0.02.0"
/*
 *  defines wishbone vendor IDs
 *  defines wishbone device IDs and registers
 *
 *
 **********************************************************************************************/
#ifndef WB_SLAVES_H_
#define WB_SLAVES_H_

#include "../ip_cores/wr-cores/modules/wr_eca/eca_regs.h"

/****************************************** vendor IDs ****************************************/
#define WB_CERN         0xce42
#define WB_GSI          0x0651

/****************************************** devices *******************************************/

/*** WR-PPS-Generator ***/
/* device ID */
#define WR_PPS_GEN_VENDOR       WB_CERN     /* vendor ID */
#define WR_PPS_GEN_PRODUCT      0xde0d8ced  /* product ID */
#define WR_PPS_GEN_VMAJOR      	1           /* major revision */
#define WR_PPS_GEN_VMINOR      	1           /* minor revision */

/* register offsets, see ip_cores/wrpc-sw/include/hw/pps_gen_regs.h */
#define WR_PPS_GEN_CNTR_UTCLO   0x8         /* UTC seconds low bytes */
#define WR_PPS_GEN_CNTR_UTCHI   0xc         /* UTC seconds high bytes */
#define WR_PPS_GEN_CNTR_NSEC    0x4         /* UTC nanoseconds */
#define WR_PPS_GEN_ESCR         0x1c        /* External Sync Control Register */

/* masks */
#define WR_PPS_GEN_ESCR_MASKSYN 0x1         /* sync to external PPS */
#define WR_PPS_GEN_ESCR_MASKPPS 0x2         /* PPS valid bit */
#define WR_PPS_GEN_ESCR_MASKTS  0x4         /* timestamp valid bit */
#define WR_PPS_GEN_ESCR_MASK    0x6         /* bit 1: PPS valid, bit 2: timestamp valid */


/*** WR-Endpoint ***/
/* device ID */
#define WR_ENDPOINT_VENDOR      WB_CERN     /* vendor ID */
#define WR_ENDPOINT_PRODUCT     0x650c2d4f  /* device ID */
#define WR_ENDPOINT_VMAJOR      1           /* major revision */
#define WR_ENDPOINT_VMINOR      1           /* minor revision */

/* register offsets  */
#define WR_ENDPOINT_MACHI       0x24        /* MAC high bytes */
#define WR_ENDPOINT_MACLO       0x28        /* MAC low bytes */
#define WR_ENDPOINT_LINK        0x30        /* link status */

/* masks */
#define WR_ENDPOINT_MACHI_MASK  0x0000ffff  /* only two bytes are of interest */
#define WR_ENDPOINT_LINK_MASK   0x000000a0  /* only this bit */



/*** Etherbone-Config ***/
/* device ID */
#define ETHERBONE_CONFIG_VENDOR       	 WB_GSI      /* vendor ID */
#define ETHERBONE_CONFIG_PRODUCT       	 0x68202b22  /* product ID */
#define ETHERBONE_CONFIG_VMAJOR      	 1           /* major revision */
#define ETHERBONE_CONFIG_VMINOR      	 1           /* minor revision */

/* register offsets */
#define ETHERBONE_CONFIG_IP              0x18        /* IP address in hex */

/* masks */



/*** LM32-RAM-User ***/
/* device ID */
#define LM32_RAM_USER_VENDOR      WB_GSI             /* vendor ID */
#define LM32_RAM_USER_PRODUCT     0x54111351         /* product ID */
#define LM32_RAM_USER_VMAJOR      1                  /* major revision */
#define LM32_RAM_USER_VMINOR      0                  /* minor revision */


/* register offsets */

/* masks */



/*** WB4-BlockRAM ***/
/* device ID */
#define WB4_BLOCKRAM_VENDOR      WB_CERN             /* vendor ID */
#define WB4_BLOCKRAM_PRODUCT     0x66cfeb52          /* product ID */
#define WB4_BLOCKRAM_VMAJOR      1                   /* major revision */
#define WB4_BLOCKRAM_VMINOR      1                   /* minor revision */

/* register offsets */
#define WB4_BLOCKRAM_WR_UPTIME   0xa0                /* uptime of WR */

/* masks */



/*** WR-Periph-1Wire ***/
/* device ID */
#define WB4_PERIPH_1WIRE_VENDOR      WB_CERN             /* vendor ID */
#define WB4_PERIPH_1WIRE_PRODUCT     0x779c5443          /* product ID */
#define WB4_PERIPH_1WIRE_VMAJOR      1                   /* major revision */
#define WB4_PERIPH_1WIRE_VMINOR      1                   /* minor revision */

/* register offsets */

/* masks */


/*** ECA  ***/
/* device ID */
#define ECA_CTRL_VENDOR              WB_GSI              /* vendor ID */
#define ECA_CTRL_PRODUCT             ECA_SDB_DEVICE_ID   /* product ID */
#define ECA_CTRL_VMAJOR              1                   /* major revision */
#define ECA_CTRL_VMINOR              0                   /* minor revision */

/* register offsets */
#define ECA_CTRL_TIME_HI_GET         ECA_TIME_HI_GET     /* UTC high 32 bit */
#define ECA_CTRL_TIME_LO_GET         ECA_TIME_LO_GET     /* UTC low  32 bit */

/* masks */



#endif  /* wb_slaves.h */

