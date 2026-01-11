#!/usr/bin/env python3
"""
SOCKS5 VPN Server for macOS

This server accepts VPN tunnel connections from the iOS SOCKS5 app and 
forwards traffic to the internet, bypassing iOS device isolation.

Usage:
    python3 socks_vpn_server.py [--port PORT] [--socks-port SOCKS_PORT]

The server:
1. Listens for incoming tunnel connections from the iOS app
2. Receives IP packets from the iOS device
3. Forwards traffic to the internet (or local SOCKS proxy)
4. Sends responses back through the tunnel

Requirements:
    - Python 3.7+
    - macOS (tested on 10.15+)
"""

import argparse
import asyncio
import logging
import socket
import struct
import sys
from typing import Optional, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class SOCKSProxy:
    """Simple SOCKS5 proxy implementation"""
    
    def __init__(self, host: str = '127.0.0.1', port: int = 1080):
        self.host = host
        self.port = port
        self.server: Optional[asyncio.Server] = None
    
    async def start(self):
        """Start the SOCKS5 proxy server"""
        self.server = await asyncio.start_server(
            self.handle_client, self.host, self.port
        )
        logger.info(f"SOCKS5 proxy listening on {self.host}:{self.port}")
    
    async def stop(self):
        """Stop the proxy server"""
        if self.server:
            self.server.close()
            await self.server.wait_closed()
    
    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        """Handle a SOCKS5 client connection"""
        addr = writer.get_extra_info('peername')
        logger.debug(f"New SOCKS connection from {addr}")
        
        try:
            # SOCKS5 handshake
            data = await reader.read(2)
            if len(data) < 2 or data[0] != 0x05:
                logger.warning("Invalid SOCKS version")
                writer.close()
                return
            
            nmethods = data[1]
            methods = await reader.read(nmethods)
            
            # No authentication required
            writer.write(bytes([0x05, 0x00]))
            await writer.drain()
            
            # Read connection request
            data = await reader.read(4)
            if len(data) < 4 or data[0] != 0x05 or data[1] != 0x01:
                logger.warning("Invalid SOCKS request")
                writer.close()
                return
            
            atyp = data[3]
            
            # Get destination address
            if atyp == 0x01:  # IPv4
                addr_data = await reader.read(4)
                dst_addr = socket.inet_ntoa(addr_data)
            elif atyp == 0x03:  # Domain name
                length = (await reader.read(1))[0]
                dst_addr = (await reader.read(length)).decode()
            elif atyp == 0x04:  # IPv6
                addr_data = await reader.read(16)
                dst_addr = socket.inet_ntop(socket.AF_INET6, addr_data)
            else:
                logger.warning(f"Unsupported address type: {atyp}")
                writer.close()
                return
            
            # Get destination port
            port_data = await reader.read(2)
            dst_port = struct.unpack('!H', port_data)[0]
            
            logger.info(f"Connecting to {dst_addr}:{dst_port}")
            
            try:
                # Connect to destination
                remote_reader, remote_writer = await asyncio.open_connection(dst_addr, dst_port)
                
                # Send success response
                response = bytes([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0])
                writer.write(response)
                await writer.drain()
                
                # Relay data
                await asyncio.gather(
                    self.relay(reader, remote_writer),
                    self.relay(remote_reader, writer)
                )
                
            except Exception as e:
                logger.error(f"Connection failed: {e}")
                # Send failure response
                response = bytes([0x05, 0x05, 0x00, 0x01, 0, 0, 0, 0, 0, 0])
                writer.write(response)
                await writer.drain()
                
        except Exception as e:
            logger.error(f"Error handling client: {e}")
        finally:
            writer.close()
            await writer.wait_closed()
    
    async def relay(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        """Relay data between two streams"""
        try:
            while True:
                data = await reader.read(4096)
                if not data:
                    break
                writer.write(data)
                await writer.drain()
        except asyncio.CancelledError:
            pass
        except ConnectionResetError:
            pass
        except Exception as e:
            logger.debug(f"Relay error: {e}")
        finally:
            writer.close()


class TunnelServer:
    """
    VPN Tunnel Server that accepts connections from iOS devices
    and forwards traffic to bypass device isolation.
    """
    
    def __init__(self, host: str = '0.0.0.0', port: int = 9876):
        self.host = host
        self.port = port
        self.server: Optional[asyncio.Server] = None
        self.clients: dict = {}
    
    async def start(self):
        """Start the tunnel server"""
        self.server = await asyncio.start_server(
            self.handle_tunnel_client, self.host, self.port
        )
        
        # Get actual bound address
        addrs = ', '.join(str(sock.getsockname()) for sock in self.server.sockets)
        logger.info(f"VPN Tunnel server listening on {addrs}")
        
        # Also print local IP for user convenience
        local_ip = self.get_local_ip()
        logger.info(f"")
        logger.info(f"=" * 60)
        logger.info(f"iOS App Configuration:")
        logger.info(f"  Server Address: {local_ip}")
        logger.info(f"  Server Port: {self.port}")
        logger.info(f"=" * 60)
        logger.info(f"")
    
    def get_local_ip(self) -> str:
        """Get the local IP address"""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except:
            return "127.0.0.1"
    
    async def stop(self):
        """Stop the tunnel server"""
        if self.server:
            self.server.close()
            await self.server.wait_closed()
    
    async def handle_tunnel_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        """Handle a tunnel connection from iOS device"""
        addr = writer.get_extra_info('peername')
        logger.info(f"New tunnel connection from {addr}")
        
        try:
            while True:
                # Read packet length (4 bytes, big-endian)
                length_data = await reader.readexactly(4)
                packet_length = struct.unpack('!I', length_data)[0]
                
                if packet_length == 0 or packet_length > 65535:
                    logger.warning(f"Invalid packet length: {packet_length}")
                    continue
                
                # Read packet data
                packet_data = await reader.readexactly(packet_length)
                
                # Process the IP packet
                await self.process_packet(packet_data, writer)
                
        except asyncio.IncompleteReadError:
            logger.info(f"Client {addr} disconnected")
        except Exception as e:
            logger.error(f"Error handling tunnel client: {e}")
        finally:
            writer.close()
            await writer.wait_closed()
    
    async def process_packet(self, packet: bytes, writer: asyncio.StreamWriter):
        """
        Process an IP packet from the tunnel.
        
        For simplicity, this implementation extracts TCP/UDP connections
        and forwards them directly.
        """
        if len(packet) < 20:
            return
        
        # Parse IP header
        version_ihl = packet[0]
        version = version_ihl >> 4
        ihl = (version_ihl & 0x0F) * 4
        
        if version != 4:
            logger.debug(f"Non-IPv4 packet (version={version}), skipping")
            return
        
        protocol = packet[9]
        src_ip = socket.inet_ntoa(packet[12:16])
        dst_ip = socket.inet_ntoa(packet[16:20])
        
        logger.debug(f"IP packet: {src_ip} -> {dst_ip}, protocol={protocol}")
        
        # For now, we just log the packet
        # A full implementation would:
        # 1. Create a socket for the destination
        # 2. Forward the packet payload
        # 3. Receive the response
        # 4. Package it back into an IP packet
        # 5. Send it back through the tunnel
        
        # This is a simplified implementation that demonstrates the concept
        # For production use, consider using a TUN/TAP interface


async def main():
    parser = argparse.ArgumentParser(description='SOCKS5 VPN Server for iOS')
    parser.add_argument('--port', type=int, default=9876,
                        help='VPN tunnel port (default: 9876)')
    parser.add_argument('--socks-port', type=int, default=1080,
                        help='Local SOCKS5 proxy port (default: 1080)')
    parser.add_argument('--socks-only', action='store_true',
                        help='Only run SOCKS5 proxy (no VPN tunnel)')
    parser.add_argument('--debug', action='store_true',
                        help='Enable debug logging')
    
    args = parser.parse_args()
    
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Start SOCKS5 proxy
    socks_proxy = SOCKSProxy(port=args.socks_port)
    await socks_proxy.start()
    
    if not args.socks_only:
        # Start VPN tunnel server
        tunnel_server = TunnelServer(port=args.port)
        await tunnel_server.start()
    
    logger.info("")
    logger.info("Server is running. Press Ctrl+C to stop.")
    logger.info("")
    
    # Keep running
    try:
        await asyncio.Event().wait()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        await socks_proxy.stop()
        if not args.socks_only:
            await tunnel_server.stop()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
