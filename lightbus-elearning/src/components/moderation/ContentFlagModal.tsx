'use client'

import { useState } from 'react'
import { supabase } from '@/lib/supabase'
import { ContentFlagModalProps } from '@/types'
import Button from '@/components/ui/Button'
import Modal from '@/components/ui/Modal'

const ContentFlagModal: React.FC<ContentFlagModalProps> = ({
  isOpen,
  onClose,
  contentType,
  contentId,
  onSubmit
}) => {
  const [formData, setFormData] = useState({
    flag_category: '',
    flag_reason: '',
    evidence_text: '',
    anonymous_report: false
  })
  const [loading, setLoading] = useState(false)

  const flagCategories = [
    { value: 'inappropriate', label: 'Inappropriate Content', description: 'Content that violates community guidelines' },
    { value: 'incorrect', label: 'Incorrect Information', description: 'Factually incorrect or misleading content' },
    { value: 'spam', label: 'Spam', description: 'Repetitive, promotional, or off-topic content' },
    { value: 'offensive', label: 'Offensive Language', description: 'Hate speech, profanity, or discriminatory content' },
    { value: 'copyright', label: 'Copyright Violation', description: 'Unauthorized use of copyrighted material' },
    { value: 'misleading', label: 'Misleading', description: 'Content designed to deceive or misinform' },
    { value: 'other', label: 'Other', description: 'Other issues not covered above' }
  ]

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!formData.flag_category || !formData.flag_reason.trim()) {
      return
    }

    setLoading(true)
    
    try {
      const { data, error } = await supabase.rpc('flag_content', {
        p_content_type: contentType,
        p_content_id: contentId,
        p_flag_category: formData.flag_category,
        p_flag_reason: formData.flag_reason,
        p_evidence_text: formData.evidence_text || null,
        p_anonymous: formData.anonymous_report
      })

      if (error) throw error

      onSubmit({
        content_type: contentType as any,
        content_id: contentId,
        flag_category: formData.flag_category as any,
        flag_reason: formData.flag_reason,
        evidence_text: formData.evidence_text,
        anonymous_report: formData.anonymous_report
      })

      // Reset form
      setFormData({
        flag_category: '',
        flag_reason: '',
        evidence_text: '',
        anonymous_report: false
      })

      onClose()
    } catch (error) {
      console.error('Error submitting flag:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleChange = (field: string, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }))
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Report Content"
      size="lg"
    >
      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <svg className="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
                <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
            </div>
            <div className="ml-3">
              <h3 className="text-sm font-medium text-yellow-800">
                Report Guidelines
              </h3>
              <div className="mt-2 text-sm text-yellow-700">
                <p>
                  Please only report content that violates our community guidelines. 
                  False reports may result in action against your account.
                </p>
              </div>
            </div>
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-3">
            What's wrong with this content? *
          </label>
          <div className="space-y-3">
            {flagCategories.map((category) => (
              <label
                key={category.value}
                className={`flex items-start p-3 border rounded-lg cursor-pointer transition-colors ${
                  formData.flag_category === category.value
                    ? 'border-blue-500 bg-blue-50'
                    : 'border-gray-200 hover:border-gray-300'
                }`}
              >
                <input
                  type="radio"
                  name="flag_category"
                  value={category.value}
                  checked={formData.flag_category === category.value}
                  onChange={(e) => handleChange('flag_category', e.target.value)}
                  className="mt-1 h-4 w-4 text-blue-600 border-gray-300 focus:ring-blue-500"
                />
                <div className="ml-3">
                  <div className="text-sm font-medium text-gray-900">
                    {category.label}
                  </div>
                  <div className="text-sm text-gray-500">
                    {category.description}
                  </div>
                </div>
              </label>
            ))}
          </div>
        </div>

        <div>
          <label htmlFor="flag_reason" className="block text-sm font-medium text-gray-700 mb-2">
            Please explain the issue *
          </label>
          <textarea
            id="flag_reason"
            value={formData.flag_reason}
            onChange={(e) => handleChange('flag_reason', e.target.value)}
            className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            rows={4}
            placeholder="Describe what's wrong with this content..."
            required
          />
        </div>

        <div>
          <label htmlFor="evidence_text" className="block text-sm font-medium text-gray-700 mb-2">
            Additional evidence (optional)
          </label>
          <textarea
            id="evidence_text"
            value={formData.evidence_text}
            onChange={(e) => handleChange('evidence_text', e.target.value)}
            className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            rows={3}
            placeholder="Any additional context, links, or evidence..."
          />
          <p className="mt-1 text-xs text-gray-500">
            Include any relevant details that help moderators understand the issue
          </p>
        </div>

        <div className="flex items-center">
          <input
            id="anonymous_report"
            type="checkbox"
            checked={formData.anonymous_report}
            onChange={(e) => handleChange('anonymous_report', e.target.checked)}
            className="h-4 w-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
          />
          <label htmlFor="anonymous_report" className="ml-2 block text-sm text-gray-700">
            Submit this report anonymously
          </label>
        </div>

        <div className="bg-gray-50 p-4 rounded-lg">
          <h4 className="text-sm font-medium text-gray-900 mb-2">What happens next?</h4>
          <ul className="text-sm text-gray-600 space-y-1">
            <li>• Your report will be reviewed by our moderation team</li>
            <li>• We'll investigate the content within 24 hours</li>
            <li>• You'll receive an update on the outcome (unless anonymous)</li>
            <li>• Appropriate action will be taken if guidelines are violated</li>
          </ul>
        </div>

        <div className="flex justify-end space-x-3 pt-4 border-t border-gray-200">
          <Button
            type="button"
            variant="secondary"
            onClick={onClose}
            disabled={loading}
          >
            Cancel
          </Button>
          <Button
            type="submit"
            variant="primary"
            loading={loading}
            disabled={!formData.flag_category || !formData.flag_reason.trim()}
          >
            Submit Report
          </Button>
        </div>
      </form>
    </Modal>
  )
}

export default ContentFlagModal