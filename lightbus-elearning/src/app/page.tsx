import Link from 'next/link'
import Button from '@/components/ui/Button'
import Card from '@/components/ui/Card'

export default function HomePage() {
  return (
    <div>
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-learning-50 to-achievement-50 py-20">
        <div className="container-main">
          <div className="text-center max-w-4xl mx-auto">
            <h1 className="heading-1 mb-6">
              Master Any Subject with{' '}
              <span className="text-learning-500">Scientifically-Proven</span>{' '}
              Spaced Repetition
            </h1>
            <p className="body-large text-neutral-gray mb-8 max-w-2xl mx-auto">
              Light Bus transforms how you learn by using advanced algorithms to show you information 
              exactly when you're about to forget it. Study smarter, not harder.
            </p>
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link href="/auth/register">
                <Button variant="primary" size="lg">
                  Start Learning Free
                </Button>
              </Link>
              <Link href="/demo">
                <Button variant="ghost" size="lg">
                  Watch Demo
                </Button>
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 bg-white">
        <div className="container-main">
          <div className="text-center mb-16">
            <h2 className="heading-2 mb-4">Why Choose Light Bus?</h2>
            <p className="body-large text-neutral-gray max-w-2xl mx-auto">
              Our platform combines cutting-edge learning science with an intuitive interface 
              designed for maximum retention and motivation.
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <Card variant="default" padding="lg" hover className="text-center">
              <div className="bg-learning-500 text-white w-16 h-16 mx-auto mb-6 flex items-center justify-center text-2xl font-bold">
                🧠
              </div>
              <h3 className="heading-4 mb-4">Spaced Repetition Algorithm</h3>
              <p className="text-neutral-gray">
                Based on the SM-2 algorithm, our system calculates the optimal time to review 
                each flashcard for maximum retention.
              </p>
            </Card>

            <Card variant="default" padding="lg" hover className="text-center">
              <div className="bg-achievement-500 text-white w-16 h-16 mx-auto mb-6 flex items-center justify-center text-2xl font-bold">
                ⚡
              </div>
              <h3 className="heading-4 mb-4">Energetic Clarity Design</h3>
              <p className="text-neutral-gray">
                Clean, motivating interface with pronounced edges and vibrant colors 
                designed to keep you focused and engaged.
              </p>
            </Card>

            <Card variant="default" padding="lg" hover className="text-center">
              <div className="bg-focus-500 text-white w-16 h-16 mx-auto mb-6 flex items-center justify-center text-2xl font-bold">
                📊
              </div>
              <h3 className="heading-4 mb-4">Progress Tracking</h3>
              <p className="text-neutral-gray">
                Detailed analytics show your learning progress, streak tracking, 
                and personalized insights to optimize your study sessions.
              </p>
            </Card>
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section className="py-20 bg-neutral-gray bg-opacity-5">
        <div className="container-main">
          <div className="text-center mb-16">
            <h2 className="heading-2 mb-4">How Light Bus Works</h2>
            <p className="body-large text-neutral-gray max-w-2xl mx-auto">
              Simple, effective learning in three steps
            </p>
          </div>

          <div className="grid md:grid-cols-3 gap-12">
            <div className="text-center">
              <div className="bg-learning-500 text-white w-12 h-12 mx-auto mb-6 flex items-center justify-center text-xl font-bold">
                1
              </div>
              <h3 className="heading-4 mb-4">Create or Import Content</h3>
              <p className="text-neutral-gray">
                Upload lesson recordings, create flashcards manually, or import from existing materials. 
                Our AI can help generate cards from your content.
              </p>
            </div>

            <div className="text-center">
              <div className="bg-achievement-500 text-white w-12 h-12 mx-auto mb-6 flex items-center justify-center text-xl font-bold">
                2
              </div>
              <h3 className="heading-4 mb-4">Study with Smart Scheduling</h3>
              <p className="text-neutral-gray">
                Review flashcards when the algorithm determines you're about to forget them. 
                Rate your confidence and the system adapts to your learning pace.
              </p>
            </div>

            <div className="text-center">
              <div className="bg-focus-500 text-white w-12 h-12 mx-auto mb-6 flex items-center justify-center text-xl font-bold">
                3
              </div>
              <h3 className="heading-4 mb-4">Track Your Progress</h3>
              <p className="text-neutral-gray">
                Monitor your learning streaks, retention rates, and areas that need more focus. 
                Celebrate achievements and stay motivated.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Social Proof Section */}
      <section className="py-20 bg-white">
        <div className="container-main">
          <div className="text-center mb-16">
            <h2 className="heading-2 mb-4">Trusted by Learners Worldwide</h2>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            <Card variant="default" padding="lg">
              <div className="flex items-center mb-4">
                <div className="w-12 h-12 bg-achievement-500 text-white flex items-center justify-center font-bold mr-4">
                  AS
                </div>
                <div>
                  <h4 className="font-semibold">Alex Smith</h4>
                  <p className="text-sm text-neutral-gray">Medical Student</p>
                </div>
              </div>
              <p className="text-neutral-gray">
                "Light Bus helped me memorize thousands of medical terms efficiently. 
                The spaced repetition really works!"
              </p>
            </Card>

            <Card variant="default" padding="lg">
              <div className="flex items-center mb-4">
                <div className="w-12 h-12 bg-learning-500 text-white flex items-center justify-center font-bold mr-4">
                  MJ
                </div>
                <div>
                  <h4 className="font-semibold">Maria Johnson</h4>
                  <p className="text-sm text-neutral-gray">Language Teacher</p>
                </div>
              </div>
              <p className="text-neutral-gray">
                "I use Light Bus to create vocabulary cards for my students. 
                The progress tracking is incredibly helpful."
              </p>
            </Card>

            <Card variant="default" padding="lg">
              <div className="flex items-center mb-4">
                <div className="w-12 h-12 bg-focus-500 text-white flex items-center justify-center font-bold mr-4">
                  DL
                </div>
                <div>
                  <h4 className="font-semibold">David Lee</h4>
                  <p className="text-sm text-neutral-gray">Software Engineer</p>
                </div>
              </div>
              <p className="text-neutral-gray">
                "Perfect for learning new programming concepts. The algorithm 
                ensures I review topics at the right time."
              </p>
            </Card>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 bg-gradient-to-r from-learning-500 to-focus-500 text-white">
        <div className="container-main text-center">
          <h2 className="heading-2 mb-4">Ready to Transform Your Learning?</h2>
          <p className="body-large mb-8 max-w-2xl mx-auto opacity-90">
            Join thousands of students and teachers who are already learning more effectively with Light Bus.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link href="/auth/register">
              <Button variant="secondary" size="lg">
                Get Started Free
              </Button>
            </Link>
            <Link href="/auth/login">
              <Button variant="ghost" size="lg" className="border-white text-white hover:bg-white hover:text-learning-500">
                Sign In
              </Button>
            </Link>
          </div>
        </div>
      </section>
    </div>
  )
}
