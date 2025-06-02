'use client'

import { useState, useEffect, useRef } from 'react'
import { supabase } from '@/lib/supabase'
import { LiveStudyRoomProps, StudyRoomEvent, SRCard } from '@/types'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'

const LiveStudyRoom: React.FC<LiveStudyRoomProps> = ({
  room,
  currentUser,
  onLeaveRoom,
  onSendMessage,
  onSyncProgress
}) => {
  const [participants, setParticipants] = useState(room.participants || [])
  const [messages, setMessages] = useState<StudyRoomEvent[]>([])
  const [currentCard, setCurrentCard] = useState<SRCard | null>(null)
  const [showAnswer, setShowAnswer] = useState(false)
  const [newMessage, setNewMessage] = useState('')
  const [sessionProgress, setSessionProgress] = useState({
    current_card_index: 0,
    total_cards: 0,
    completed_cards: 0
  })
  const [isHost, setIsHost] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    setIsHost(room.host_id === currentUser.id)
    loadStudyCards()
    subscribeToRoomEvents()
    
    return () => {
      // Cleanup subscriptions
    }
  }, [room.id, currentUser.id])

  useEffect(() => {
    scrollToBottom()
  }, [messages])

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  const loadStudyCards = async () => {
    if (!room.lesson_id) return

    try {
      const { data: cards, error } = await supabase
        .from('sr_cards')
        .select('*')
        .eq('lesson_id', room.lesson_id)
        .eq('status', 'approved')
        .order('created_at')

      if (error) throw error

      if (cards && cards.length > 0) {
        setCurrentCard(cards[0])
        setSessionProgress({
          current_card_index: 0,
          total_cards: cards.length,
          completed_cards: 0
        })
      }
    } catch (error) {
      console.error('Error loading study cards:', error)
    }
  }

  const subscribeToRoomEvents = async () => {
    // Subscribe to real-time events for this room
    const channel = supabase
      .channel(`study_room:${room.id}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'study_room_events',
          filter: `room_id=eq.${room.id}`
        },
        (payload) => {
          const newEvent = payload.new as StudyRoomEvent
          handleRoomEvent(newEvent)
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'study_room_participants',
          filter: `room_id=eq.${room.id}`
        },
        (payload) => {
          // User joined
          loadParticipants()
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'study_room_participants',
          filter: `room_id=eq.${room.id}`
        },
        (payload) => {
          // User left or updated status
          loadParticipants()
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }

  const loadParticipants = async () => {
    try {
      const { data, error } = await supabase
        .from('study_room_participants')
        .select(`
          *,
          user:profiles!study_room_participants_user_id_fkey(id, name, email)
        `)
        .eq('room_id', room.id)
        .eq('is_active', true)

      if (error) throw error
      setParticipants(data || [])
    } catch (error) {
      console.error('Error loading participants:', error)
    }
  }

  const handleRoomEvent = (event: StudyRoomEvent) => {
    switch (event.event_type) {
      case 'chat_message':
        setMessages(prev => [...prev, event])
        break
      case 'card_flip':
        if (event.event_data.synchronized) {
          setShowAnswer(event.event_data.show_answer)
        }
        break
      case 'progress_sync':
        if (event.event_data.card_index !== undefined) {
          setSessionProgress(prev => ({
            ...prev,
            current_card_index: event.event_data.card_index
          }))
          loadCardAtIndex(event.event_data.card_index)
        }
        break
      case 'user_join':
      case 'user_leave':
        loadParticipants()
        setMessages(prev => [...prev, event])
        break
    }
  }

  const loadCardAtIndex = async (index: number) => {
    if (!room.lesson_id) return

    try {
      const { data: cards, error } = await supabase
        .from('sr_cards')
        .select('*')
        .eq('lesson_id', room.lesson_id)
        .eq('status', 'approved')
        .order('created_at')
        .limit(1)
        .range(index, index)

      if (error) throw error

      if (cards && cards.length > 0) {
        setCurrentCard(cards[0])
        setShowAnswer(false)
      }
    } catch (error) {
      console.error('Error loading card at index:', error)
    }
  }

  const broadcastEvent = async (eventType: string, eventData: any) => {
    try {
      await supabase.rpc('broadcast_study_event', {
        p_room_id: room.id,
        p_event_type: eventType,
        p_event_data: eventData
      })
    } catch (error) {
      console.error('Error broadcasting event:', error)
    }
  }

  const handleFlipCard = () => {
    const newShowAnswer = !showAnswer
    setShowAnswer(newShowAnswer)
    
    // Broadcast flip event if host
    if (isHost) {
      broadcastEvent('card_flip', {
        show_answer: newShowAnswer,
        synchronized: true
      })
    }
  }

  const handleNextCard = () => {
    if (!isHost) return

    const nextIndex = sessionProgress.current_card_index + 1
    if (nextIndex < sessionProgress.total_cards) {
      setSessionProgress(prev => ({
        ...prev,
        current_card_index: nextIndex,
        completed_cards: prev.completed_cards + 1
      }))
      
      broadcastEvent('progress_sync', {
        card_index: nextIndex,
        completed_cards: sessionProgress.completed_cards + 1
      })
      
      loadCardAtIndex(nextIndex)
    }
  }

  const handlePreviousCard = () => {
    if (!isHost) return

    const prevIndex = sessionProgress.current_card_index - 1
    if (prevIndex >= 0) {
      setSessionProgress(prev => ({
        ...prev,
        current_card_index: prevIndex
      }))
      
      broadcastEvent('progress_sync', {
        card_index: prevIndex
      })
      
      loadCardAtIndex(prevIndex)
    }
  }

  const handleSendChatMessage = async () => {
    if (!newMessage.trim()) return

    const messageData = {
      message: newMessage,
      user_name: currentUser.name,
      timestamp: new Date().toISOString()
    }

    await broadcastEvent('chat_message', messageData)
    setNewMessage('')
  }

  const getParticipantStatus = (participantId: string) => {
    // This would typically show if participant is on the same card, etc.
    return 'synced' // placeholder
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Room Header */}
        <div className="mb-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">{room.name}</h1>
              <p className="text-gray-600">
                {room.description} • Room Code: <span className="font-mono font-semibold">{room.room_code}</span>
              </p>
            </div>
            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-2">
                <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                <span className="text-sm text-gray-600">{participants.length} participants</span>
              </div>
              <Button variant="secondary" onClick={onLeaveRoom}>
                Leave Room
              </Button>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
          {/* Main Study Area */}
          <div className="lg:col-span-3 space-y-6">
            {/* Progress Bar */}
            <Card className="p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium text-gray-700">Session Progress</span>
                <span className="text-sm text-gray-500">
                  {sessionProgress.current_card_index + 1} of {sessionProgress.total_cards}
                </span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div 
                  className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                  style={{ 
                    width: `${sessionProgress.total_cards > 0 ? ((sessionProgress.current_card_index + 1) / sessionProgress.total_cards) * 100 : 0}%` 
                  }}
                />
              </div>
            </Card>

            {/* Study Card */}
            {currentCard && (
              <Card className="p-8">
                <div className="text-center">
                  <div className="mb-8">
                    <div className="min-h-[200px] flex items-center justify-center">
                      {!showAnswer ? (
                        <div>
                          <h2 className="text-xl font-semibold text-gray-900 mb-4">Question</h2>
                          <div className="text-lg text-gray-700 whitespace-pre-wrap">
                            {currentCard.front_content}
                          </div>
                        </div>
                      ) : (
                        <div>
                          <h2 className="text-xl font-semibold text-gray-900 mb-4">Answer</h2>
                          <div className="text-lg text-gray-700 whitespace-pre-wrap">
                            {currentCard.back_content}
                          </div>
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center justify-center space-x-4">
                    {isHost && (
                      <Button
                        variant="secondary"
                        onClick={handlePreviousCard}
                        disabled={sessionProgress.current_card_index === 0}
                      >
                        Previous
                      </Button>
                    )}
                    
                    <Button
                      variant="primary"
                      onClick={handleFlipCard}
                      className="px-8"
                    >
                      {showAnswer ? 'Show Question' : 'Show Answer'}
                    </Button>

                    {isHost && (
                      <Button
                        variant="secondary"
                        onClick={handleNextCard}
                        disabled={sessionProgress.current_card_index >= sessionProgress.total_cards - 1}
                      >
                        Next
                      </Button>
                    )}
                  </div>

                  {!isHost && (
                    <p className="text-sm text-gray-500 mt-4">
                      The host controls the card progression
                    </p>
                  )}
                </div>
              </Card>
            )}
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Participants */}
            <Card className="p-4">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Participants</h3>
              <div className="space-y-3">
                {participants.map((participant) => (
                  <div key={participant.id} className="flex items-center justify-between">
                    <div className="flex items-center space-x-3">
                      <div className="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center">
                        <span className="text-xs font-medium text-gray-700">
                          {participant.user?.name?.charAt(0).toUpperCase()}
                        </span>
                      </div>
                      <div>
                        <p className="text-sm font-medium text-gray-900">
                          {participant.user?.name}
                          {participant.role === 'host' && (
                            <span className="ml-2 inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800">
                              Host
                            </span>
                          )}
                        </p>
                      </div>
                    </div>
                    <div className={`w-2 h-2 rounded-full ${
                      getParticipantStatus(participant.user_id) === 'synced' ? 'bg-green-500' : 'bg-yellow-500'
                    }`} />
                  </div>
                ))}
              </div>
            </Card>

            {/* Chat */}
            <Card className="p-4">
              <h3 className="text-lg font-semibold text-gray-900 mb-4">Chat</h3>
              
              {/* Messages */}
              <div className="h-64 overflow-y-auto mb-4 space-y-2">
                {messages.map((message, index) => (
                  <div key={index} className="text-sm">
                    {message.event_type === 'chat_message' ? (
                      <div>
                        <span className="font-semibold text-gray-900">
                          {message.event_data.user_name}:
                        </span>
                        <span className="text-gray-700 ml-2">
                          {message.event_data.message}
                        </span>
                      </div>
                    ) : (
                      <div className="text-gray-500 italic">
                        {message.event_type === 'user_join' && `${message.event_data.user_name} joined the room`}
                        {message.event_type === 'user_leave' && `${message.event_data.user_name} left the room`}
                      </div>
                    )}
                  </div>
                ))}
                <div ref={messagesEndRef} />
              </div>

              {/* Message Input */}
              <div className="flex space-x-2">
                <input
                  type="text"
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleSendChatMessage()}
                  placeholder="Type a message..."
                  className="flex-1 px-3 py-2 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
                <Button
                  variant="primary"
                  size="sm"
                  onClick={handleSendChatMessage}
                  disabled={!newMessage.trim()}
                >
                  Send
                </Button>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </div>
  )
}

export default LiveStudyRoom