#ifndef _NODE_H_
#define _NODE_H_
#include <string>
#include <stdint.h>
#include <stdlib.h>
#include "common.h"
#include "visitoruploadcrawler.h"
#include "visitordownloadcrawler.h"
#include "visitorvertexwriter.h"
#include "ftm_common.h"



class Node {

  const std::string&  name;
  const uint32_t&     hash;


protected:    

  uint8_t (&b)[_MEM_BLOCK_SIZE];
  uint32_t      flags;
  

  


public:
  
  Node(const std::string& name, const uint32_t& hash, uint8_t (&b)[_MEM_BLOCK_SIZE], uint32_t flags) : name(name), hash(hash), b(b), flags(flags) {} //what to do if it fails?
  virtual ~Node() {}
  virtual node_ptr clone() const = 0; 
  

  const std::string&  getName() const {return this->name;}
  const uint32_t&     getHash() const {return this->hash;}
  const uint32_t&     getFlags() const {return this->flags;}
  void     setFlags(uint32_t flags) {this->flags |= flags;}
  void     clrFlags(uint32_t flags) {this->flags &= ~flags;}
  const bool isPainted() const {return (bool)(this->flags & NFLG_PAINT_LM32_SMSK);}
  const auto getB() -> uint8_t (&)[_MEM_BLOCK_SIZE] {return this->b;}

  virtual void show(void)                               const = 0;
  virtual void show(uint32_t cnt, const char* sPrefix)  const = 0;
  virtual void accept(const VisitorVertexWriter& v)     const = 0;
  virtual void accept(const VisitorUploadCrawler& v)      const = 0;
  virtual void accept(const VisitorDownloadCrawler& v)    const = 0;
  virtual bool isMeta(void) const {return false;}
  virtual bool isBlock(void) const {return false;}
  virtual void deserialise() = 0;
  virtual void serialise(const vAdr &va) const {
  
  //   std::cout << "va: " << va.size() << std::endl;
  //FIXME size check !
  //for(auto it = va.begin(); it < va.end(); it++) std::cout << "#" << it - va.begin() << " 0x" << std::hex << *it << std::endl;
  //std::cout << std::endl;  
  
    writeLeNumberToBeBytes(b + (ptrdiff_t)NODE_DEF_DEST_PTR,  va[ADR_DEF_DST]);
    writeLeNumberToBeBytes(b + (ptrdiff_t)NODE_HASH,   this->hash);
    writeLeNumberToBeBytes(b + (ptrdiff_t)NODE_FLAGS,  this->flags);
  }

};





#endif
