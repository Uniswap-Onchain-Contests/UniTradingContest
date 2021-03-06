pragma solidity 0.7.6;

// Eth Heap
// Author: Zac Mitton
// License: MIT

library Heap{ // default max-heap

  uint constant ROOT_INDEX = 1;

  struct Data{
    Node[] nodes; // root is index 1; index 0 not used
    mapping (address => uint) indices; // unique id => node index
  }
  struct Node{
    address id; //use with another mapping to store arbitrary object types
    uint256 priority;
  }

  //call init before anything else
  function init(Data storage self) internal{
    if(self.nodes.length == 0) self.nodes.push(Node(address(0),0));
  }

  function insert(Data storage self, address id, uint256 priority) internal returns(Node memory){//√
    if(self.nodes.length == 0){ init(self); }// test on-the-fly-init
    Node memory n = Node(id, priority);
    _bubbleUp(self, n, self.nodes.length);
    return n;
  }
  function extractMax(Data storage self) internal returns(Node memory){//√
    return _extract(self, ROOT_INDEX);
  }
  function extractById(Data storage self, address id) internal returns(Node memory){//√
    return _extract(self, self.indices[id]);
  }

  //view
  function dump(Data storage self) internal view returns(Node[] memory){
  //note: Empty set will return `[Node(0,0)]`. uninitialized will return `[]`.
    return self.nodes;
  }
  function getById(Data storage self, address id) internal view returns(Node memory){
    return getByIndex(self, self.indices[id]);//test that all these return the emptyNode
  }
  function getByIndex(Data storage self, uint i) internal view returns(Node memory){
    return self.nodes.length > i ? self.nodes[i] : Node(address(0),0);
  }
  function getMax(Data storage self) internal view returns(Node memory){
    return getByIndex(self, ROOT_INDEX);
  }
  function size(Data storage self) internal view returns(uint){
    return self.nodes.length > 0 ? self.nodes.length-1 : 0;
  }
  function isNode(Node memory n) internal pure returns(bool){ return n.id != address(0); }

  //private
  function _extract(Data storage self, uint i) private returns(Node memory){//√
    if(self.nodes.length <= i || i <= 0){ return Node(address(0),0); }

    Node memory extractedNode = self.nodes[i];
    delete self.indices[extractedNode.id];
    delete self.nodes[i];

    Node memory tailNode = self.nodes[self.nodes.length-1];

    if(i < self.nodes.length){ // if extracted node was not tail
      _bubbleUp(self, tailNode, i);
      _bubbleDown(self, self.nodes[i], i); // then try bubbling down
    }
    return extractedNode;
  }

  function _bubbleUp(Data storage self, Node memory n, uint i) private{//√
    if(i==ROOT_INDEX || n.priority <= self.nodes[i/2].priority){
      _insert(self, n, i);
    }else{
      _insert(self, self.nodes[i/2], i);
      _bubbleUp(self, n, i/2);
    }
  }
  function _bubbleDown(Data storage self, Node memory n, uint i) private{//
    uint length = self.nodes.length;
    uint cIndex = i*2; // left child index

    if(length <= cIndex){
      _insert(self, n, i);
    }else{
      Node memory largestChild = self.nodes[cIndex];

      if(length > cIndex+1 && self.nodes[cIndex+1].priority > largestChild.priority ){
        largestChild = self.nodes[++cIndex];// TEST ++ gets executed first here
      }

      if(largestChild.priority <= n.priority){ //TEST: priority 0 is valid! negative ints work
        _insert(self, n, i);
      }else{
        _insert(self, largestChild, i);
        _bubbleDown(self, n, cIndex);
      }
    }
  }

  function _insert(Data storage self, Node memory n, uint i) private{//√
    if(i == self.nodes.length){
      self.nodes.push(n);
    } else {
      self.nodes[i] = n;
    }
    self.indices[n.id] = i;
  }
}