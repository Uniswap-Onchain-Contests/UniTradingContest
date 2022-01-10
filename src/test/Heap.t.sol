pragma solidity 0.7.6;
pragma abicoder v2;

import "ds-test/test.sol";
import "../libraries/Heap.sol";

contract PublicHeap{
  using Heap for Heap.Data;
  Heap.Data private data;

  constructor() public { data.init(); }

  struct Entry{
      address id;
      uint256 priority;
  }

  function heapify(Entry[] calldata priorities) public {
    for(uint i ; i < priorities.length ; i++){
      data.insert(priorities[i].id, priorities[i].priority);
    }
  }
  function insert(address id, uint256 priority) public returns(Heap.Node memory){
    return data.insert(id, priority);
  }
  function extractMax() public returns(Heap.Node memory){
    return data.extractMax();
  }
  function extractById(address id) public returns(Heap.Node memory){
    return data.extractById(id);
  }
  //view
  function dump() public view returns(Heap.Node[] memory){
    return data.dump();
  }
  function nodes() public view returns(Heap.Node[] memory){
    return data.nodes;
  }
  function getMax() public view returns(Heap.Node memory){
    return data.getMax();
  }
  function getById(address id) public view returns(Heap.Node memory){
    return data.getById(id);
  }
  function getByIndex(uint i) public view returns(Heap.Node memory){
    return data.getByIndex(i);
  }
  function size() public view returns(uint){
    return data.size();
  }
  function indices(address id) public view returns(uint){
    return data.indices[id];
  }
}
 
contract HeapTest is DSTest{
    using Heap for Heap.Data;
    PublicHeap heap = new PublicHeap();
    PublicHeap.Entry[] entries;

    function setUp() public {
        heap = new PublicHeap();
    }

    function testHeapInsert() public {
        PublicHeap.Entry memory entry1 = PublicHeap.Entry({
            id: address(1),
            priority: 4
        });
        PublicHeap.Entry memory entry2 = PublicHeap.Entry({
            id: address(2),
            priority: 3
        });
        PublicHeap.Entry memory entry3 = PublicHeap.Entry({
            id: address(3),
            priority: 5
        });
        PublicHeap.Entry memory entry4 = PublicHeap.Entry({
            id: address(4),
            priority: 1
        });
        
        entries.push(entry1);
        entries.push(entry2);
        entries.push(entry3);
        entries.push(entry4);
        heap.heapify(entries);

        assertEq(heap.getMax().id, address(3));
        assertEq(heap.extractMax().id, address(3));
        assertEq(heap.extractMax().id, address(1));
        assertEq(heap.extractMax().id, address(2));
        assertEq(heap.extractMax().id, address(4));
    }

    function testHeapExtractById() public {
        heap.insert(address(1), 1);
        // returns correctly 
        Heap.Node memory n = heap.extractById(address(1));
        assertEq(n.id, address(1));
        assertEq(n.priority, 1);
        // nodes length stays same
        Heap.Node[] memory nodes = heap.nodes();
        assertEq(nodes.length, 2);
        // extract by id again yields a struct with null values
        n = heap.extractById(address(1));
        assertEq(n.id, address(0));
        assertEq(n.priority, 0);
        // inserting behaves correctly
        heap.insert(address(2), 2);
        assertEq(heap.getMax().id, address(2));
        heap.insert(address(1), 3);
        heap.insert(address(3), 1);
        assertEq(heap.extractMax().id, address(1));
        assertEq(heap.extractMax().id, address(2));
        assertEq(heap.extractMax().id, address(3));
    }
}